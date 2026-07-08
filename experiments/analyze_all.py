"""
Pythia 多层自适应数据预取系统 — 完整实验分析脚本
======================================================================
按照 方案设计/实验方案设计.md 中的实验矩阵设计，
自动加载 rollup 输出的 CSV 数据并生成所有图/表。

用法:
    python experiments/analyze_all.py [--csv PATH] [--out DIR] [--no-4c]

默认:
    --csv  res/course_1C_results.csv
    --out  res/

支持:
    - Phase 1: 性能对比 (speedup 柱状图, heatmap, 分类汇总, 排名分布)
    - Phase 2: 预取质量分析 (Coverage/Accuracy/Timeliness/预取量)
    - Phase 3: MetaSelector 行为分析 (选择分布, 置信度, 决策分解)
    - Phase 4: 消融实验 (组件贡献瀑布图, 逐 trace 差异)
    - 统计检验: 配对 t 检验, Win/Tie/Loss 分析
"""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import csv
import os
import sys
import argparse
from collections import defaultdict, OrderedDict

try:
    from scipy import stats as scipy_stats
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False
    print("WARNING: scipy not installed — statistical tests will be skipped")

# ============================================================================
# Configuration
# ============================================================================

# Output prefix
OUT_PREFIX = ''

# Trace classification per design doc §2.3.2
TRACE_CATEGORIES = {
    'A': {  # 规则访存 — Regular patterns
        '433.milc', '462.libquantum', '470.lbm',
        'parsec_2.1.streamcluster',
    },
    'B': {  # 内存密集不规则 — Memory-intensive irregular
        '429.mcf', '605.mcf_s', '450.soplex', '483.xalancbmk',
    },
    'C': {  # 编译/服务器混合 — Compiler/Server mixed
        '403.gcc', '602.gcc_s', '471.omnetpp', '620.omnetpp_s',
        '473.astar', 'cassandra', 'nutch', 'streaming',
    },
    'D': {  # 图计算 — Graph algorithms
        'ligra_BFS', 'ligra_PageRank', 'ligra_Triangle',
        'parsec_2.1.canneal',
    },
}
TRACE_CAT_NAMES = {
    'A': 'A-规则访存 (4)',
    'B': 'B-内存密集 (4)',
    'C': 'C-混合型 (8)',
    'D': 'D-图计算 (4)',
}

# All known experiments in display order
ALL_EXPS = [
    'nopref', 'spp', 'bingo', 'mlop', 'dspatch', 'spp_ppf_dev',
    'pythia', 'linucb', 'tsetlin', 'meta_selector',
]
ALL_EXP_LABELS = {
    'nopref': 'NoPref', 'spp': 'SPP', 'bingo': 'Bingo', 'mlop': 'MLOP',
    'dspatch': 'DSPatch', 'spp_ppf_dev': 'SPP-PPF', 'pythia': 'Pythia',
    'linucb': 'LinUCB', 'tsetlin': 'Tsetlin', 'meta_selector': 'MetaSelector',
}
ALL_COLORS = {
    'nopref': '#888888', 'spp': '#e41a1c', 'bingo': '#377eb8', 'mlop': '#4daf4a',
    'dspatch': '#ffd700', 'spp_ppf_dev': '#00ced1', 'pythia': '#ff7f00',
    'linucb': '#984ea3', 'tsetlin': '#a65628', 'meta_selector': '#8b0000',
}

# Ablation experiments
ABLATION_EXPS = {
    'tsetlin_no_dyn_deg':     ('Tsetlin', 'Tsetlin-NoDynDeg'),
    'linucb_no_dyn_deg':      ('LinUCB', 'LinUCB-NoDynDeg'),
    'tsetlin_no_featurewise': ('Tsetlin', 'Tsetlin-NoFW'),
    'linucb_no_featurewise':  ('LinUCB', 'LinUCB-NoFW'),
    'linucb_no_suppress':     ('LinUCB', 'LinUCB-NoSuppress'),
    'meta_selector_no_explore': ('MetaSelector', 'MetaSel-NoExplore'),
}

# ============================================================================
# Data Loading
# ============================================================================

def load_csv(filepath):
    """Load rollup CSV with named columns."""
    rows = []
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader, None)
        if header is None:
            return [], []
        # Clean header whitespace
        header = [h.strip() for h in header]
        col_map = {name: idx for idx, name in enumerate(header)}

        for line in reader:
            if not line or len(line) < 3:
                continue
            row = {}
            for col_name, idx in col_map.items():
                if idx < len(line):
                    val = line[idx].strip()
                    try:
                        row[col_name] = float(val)
                    except ValueError:
                        row[col_name] = 0.0 if val == '' else val
                else:
                    row[col_name] = 0.0
            rows.append(row)
    return rows, header


def safe_float(row, key, default=0.0):
    """Safely get a float value from a row dict."""
    v = row.get(key, default)
    if isinstance(v, (int, float)):
        return float(v)
    return default


def get_category(trace_name):
    """Determine trace category (A/B/C/D) from name."""
    for cat, patterns in TRACE_CATEGORIES.items():
        for p in patterns:
            if p in trace_name:
                return cat
    return 'C'  # default to mixed


def get_short_name(trace):
    """Short display name for a trace."""
    mapping = {
        '403.gcc': '403.gcc', '429.mcf': '429.mcf',
        '433.milc': '433.milc', '450.soplex': '450.soplex',
        '462.libquantum': '462.libq', '470.lbm': '470.lbm',
        '471.omnetpp': '471.omnet', '473.astar': '473.astar',
        '483.xalancbmk': '483.xalan',
        '602.gcc_s': '602.gcc_s', '605.mcf_s': '605.mcf_s',
        '620.omnetpp_s': '620.omnet_s',
    }
    for k, v in mapping.items():
        if k in trace:
            return v
    if 'cassandra' in trace: return 'Cassandra'
    if 'nutch' in trace: return 'Nutch'
    if 'streaming' in trace: return 'Streaming'
    if 'BFS' in trace: return 'ligra_BFS'
    if 'PageRank' in trace: return 'ligra_PR'
    if 'Triangle' in trace: return 'ligra_Tri'
    if 'canneal' in trace: return 'canneal'
    if 'streamcluster' in trace: return 'streamcl'
    return trace[:20]


# ============================================================================
# Data Access Helpers
# ============================================================================

class ExperimentData:
    """Organized access to experiment results."""

    def __init__(self, rows):
        self.rows = rows
        self.traces = sorted(set(r['Trace'] for r in rows if safe_float(r, 'Core_0_IPC') > 0))

        # Detect available experiments
        self.exps = []
        for e in ALL_EXPS:
            if any(r['Exp'] == e for r in rows if safe_float(r, 'Core_0_IPC') > 0):
                self.exps.append(e)

        # Also detect ablation experiments
        self.ablation_exps = []
        for a in ABLATION_EXPS:
            if any(r['Exp'] == a for r in rows if safe_float(r, 'Core_0_IPC') > 0):
                self.ablation_exps.append(a)

        # Detect BW modes
        self.mtps_modes = [('', 'Baseline (2400 MTPS)')]
        if any(r['Exp'].endswith('_MTPS600') for r in rows if safe_float(r, 'Core_0_IPC') > 0):
            self.mtps_modes.append(('_MTPS600', 'Low BW (600 MTPS)'))
        if any(r['Exp'].endswith('_MTPS4800') for r in rows if safe_float(r, 'Core_0_IPC') > 0):
            self.mtps_modes.append(('_MTPS4800', 'High BW (4800 MTPS)'))

        # Index by (trace, exp) for fast lookup
        self._idx = {}
        for r in rows:
            key = (r['Trace'], r['Exp'])
            self._idx[key] = r

    def get(self, trace, exp):
        """Get the full row for a trace+exp combination."""
        return self._idx.get((trace, exp), None)

    def get_ipc(self, trace, exp):
        """Get IPC value."""
        r = self.get(trace, exp)
        if r is None:
            return None
        return safe_float(r, 'Core_0_IPC')

    def get_speedup(self, trace, exp, mtps_suffix=''):
        """Get speedup vs nopref for the same BW mode."""
        r = self.get(trace, exp + mtps_suffix)
        n = self.get(trace, 'nopref' + mtps_suffix)
        if r is None or n is None:
            return None
        ipc = safe_float(r, 'Core_0_IPC')
        nopref_ipc = safe_float(n, 'Core_0_IPC')
        if nopref_ipc <= 0:
            return None
        return (ipc / nopref_ipc - 1) * 100

    def get_accuracy(self, trace, exp, mtps_suffix=''):
        """L2C prefetch accuracy = useful / issued * 100."""
        r = self.get(trace, exp + mtps_suffix)
        if r is None:
            return None
        issued = safe_float(r, 'Core_0_L2C_prefetch_issued')
        useful = safe_float(r, 'Core_0_L2C_prefetch_useful')
        if issued <= 0:
            return 0.0
        return useful / issued * 100

    def get_timeliness(self, trace, exp, mtps_suffix=''):
        """Timeliness = (useful - late) / useful * 100."""
        r = self.get(trace, exp + mtps_suffix)
        if r is None:
            return None
        useful = safe_float(r, 'Core_0_L2C_prefetch_useful')
        late = safe_float(r, 'Core_0_L2C_prefetch_late')
        if useful <= 0:
            return 0.0
        return (useful - late) / useful * 100

    def get_coverage(self, trace, exp, mtps_suffix=''):
        """Coverage = (LLC_miss_nopref - LLC_miss_X) / LLC_miss_nopref."""
        r = self.get(trace, exp + mtps_suffix)
        n = self.get(trace, 'nopref' + mtps_suffix)
        if r is None or n is None:
            return None
        miss = safe_float(r, 'Core_0_LLC_load_miss')
        nopref_miss = safe_float(n, 'Core_0_LLC_load_miss')
        if nopref_miss <= 0:
            return None
        return (nopref_miss - miss) / nopref_miss * 100

    def get_overprediction(self, trace, exp, mtps_suffix=''):
        """Overprediction = (LLC_miss_X - LLC_miss_nopref) / LLC_miss_nopref."""
        r = self.get(trace, exp + mtps_suffix)
        n = self.get(trace, 'nopref' + mtps_suffix)
        if r is None or n is None:
            return None
        miss = safe_float(r, 'Core_0_LLC_load_miss')
        nopref_miss = safe_float(n, 'Core_0_LLC_load_miss')
        if nopref_miss <= 0:
            return None
        return max(0, (miss - nopref_miss) / nopref_miss * 100)

    def get_waste(self, trace, exp, mtps_suffix=''):
        """Waste = issued - useful."""
        r = self.get(trace, exp + mtps_suffix)
        if r is None:
            return None
        return safe_float(r, 'Core_0_L2C_prefetch_issued') - safe_float(r, 'Core_0_L2C_prefetch_useful')

    def get_llc_miss(self, trace, exp, mtps_suffix=''):
        """LLC load miss count."""
        r = self.get(trace, exp + mtps_suffix)
        if r is None:
            return None
        return safe_float(r, 'Core_0_LLC_load_miss')

    def get_l2c_miss(self, trace, exp, mtps_suffix=''):
        """L2C load miss count."""
        r = self.get(trace, exp + mtps_suffix)
        if r is None:
            return None
        return safe_float(r, 'Core_0_L2C_load_miss')

    def get_meta_selected(self, trace, exp_mtps, sub_name):
        """MetaSelector selection count for a sub-prefetcher."""
        r = self.get(trace, exp_mtps)
        if r is None:
            return None
        return safe_float(r, f'meta_selected_{sub_name}')

    def get_meta_selected_pct(self, trace, exp_mtps, sub_name):
        """MetaSelector selection pct for a sub-prefetcher."""
        r = self.get(trace, exp_mtps)
        if r is None:
            return None
        return safe_float(r, f'meta_selected_pct_{sub_name}')

    def get_meta_stat(self, trace, exp_mtps, stat_name):
        """Generic MetaSelector stat."""
        r = self.get(trace, exp_mtps)
        if r is None:
            return None
        return safe_float(r, f'meta_{stat_name}')

    def list_nonzero(self, exp, metric_fn, mtps_suffix=''):
        """Return list of (trace, value) for non-None values."""
        result = []
        for t in self.traces:
            v = metric_fn(t, exp, mtps_suffix)
            if v is not None:
                result.append((t, v))
        return result

    def geomean(self, values):
        """Geometric mean of a list of values."""
        vals = [v for v in values if v is not None and v > 0]
        if not vals:
            return 0.0
        return np.exp(np.mean(np.log(vals)))

    def mean(self, values):
        """Arithmetic mean, ignoring None."""
        vals = [v for v in values if v is not None]
        if not vals:
            return 0.0
        return np.mean(vals)


# ============================================================================
# Plotting Setup
# ============================================================================

def setup_plots():
    os.makedirs('res', exist_ok=True)
    plt.rcParams.update({
        'font.size': 10, 'axes.titlesize': 13, 'axes.labelsize': 11,
        'figure.dpi': 150, 'savefig.dpi': 150, 'savefig.bbox': 'tight',
        'font.family': 'DejaVu Sans',
    })


# ============================================================================
# Phase 1: Performance Comparison Charts
# ============================================================================

def chart_speedup_overall(data):
    """Chart 1: Overall average speedup by BW mode (bar chart)."""
    n_modes = len(data.mtps_modes)
    fig, axes = plt.subplots(1, n_modes, figsize=(7 * n_modes, 6), squeeze=False)
    axes = axes.flatten()
    fig.suptitle('Average IPC Speedup vs NoPref by DRAM Bandwidth', fontweight='bold', fontsize=14)

    for ax_idx, (mtps_suffix, mtps_name) in enumerate(data.mtps_modes):
        ax = axes[ax_idx]
        x = np.arange(len(data.exps))
        avg_speedups = []
        for exp in data.exps:
            vals = [data.get_speedup(t, exp, mtps_suffix) for t in data.traces]
            vals = [v for v in vals if v is not None]
            avg_speedups.append(np.mean(vals) if vals else 0)

        bars = ax.bar(x, avg_speedups, color=[ALL_COLORS.get(e, '#888') for e in data.exps],
                      edgecolor='white', linewidth=0.5)

        # Highlight ML experiments
        ml_indices = [i for i, e in enumerate(data.exps) if e in ('pythia', 'linucb', 'tsetlin')]
        for i in ml_indices:
            bars[i].set_edgecolor('black')
            bars[i].set_linewidth(2.5)

        for i, (bar, v) in enumerate(zip(bars, avg_speedups)):
            ax.text(bar.get_x() + bar.get_width()/2, v + 0.5, f'{v:.1f}%',
                    ha='center', va='bottom', fontsize=8,
                    fontweight='bold' if i in ml_indices else 'normal')

        ax.set_xticks(x)
        ax.set_xticklabels([ALL_EXP_LABELS.get(e, e) for e in data.exps],
                           rotation=30, ha='right', fontsize=9)
        ax.set_ylabel('Speedup vs NoPref (%)')
        ax.set_title(mtps_name, fontweight='bold')
        ax.axhline(y=0, color='black', linewidth=0.5)
        ax.grid(axis='y', alpha=0.3)

    for ax_idx in range(n_modes, len(axes)):
        axes[ax_idx].set_visible(False)

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart1_speedup_overall.png')
    plt.close(fig)
    print(f"  Chart 1 saved: res/{OUT_PREFIX}chart1_speedup_overall.png")


def chart_speedup_heatmap(data):
    """Chart 2: Per-trace IPC speedup heatmap (baseline BW)."""
    if len(data.exps) <= 1:
        return

    fig, ax = plt.subplots(figsize=(22, max(8, 0.5 * len(data.exps))))
    heatmap_exps = [e for e in data.exps if e != 'nopref']
    heatmap_data = []
    for exp in heatmap_exps:
        row = [data.get_speedup(t, exp) or 0 for t in data.traces]
        heatmap_data.append(row)

    data_arr = np.array(heatmap_data)
    im = ax.imshow(data_arr, cmap='RdYlGn', aspect='auto', vmin=-30, vmax=80)

    ax.set_xticks(range(len(data.traces)))
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_yticks(range(len(heatmap_exps)))
    ax.set_yticklabels([ALL_EXP_LABELS.get(e, e) for e in heatmap_exps], fontsize=10)
    ax.set_title('IPC Speedup vs NoPref — Baseline DRAM BW (Green=Better, Red=Worse)',
                 fontweight='bold', fontsize=14)

    for i in range(len(heatmap_exps)):
        for j in range(len(data.traces)):
            v = data_arr[i, j]
            color = 'white' if v < -10 or v > 50 else 'black'
            ax.text(j, i, f'{v:.1f}', ha='center', va='center',
                    fontsize=7, color=color, fontweight='bold')

    cbar = plt.colorbar(im, ax=ax, shrink=0.8)
    cbar.set_label('Speedup (%)')
    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart2_heatmap.png')
    plt.close(fig)
    print(f"  Chart 2 saved: res/{OUT_PREFIX}chart2_heatmap.png")


def chart_category_summary(data):
    """Chart 3: Geomean speedup by trace category A/B/C/D."""
    n_modes = len(data.mtps_modes)
    n_cats = len(TRACE_CATEGORIES)
    fig, axes = plt.subplots(1, n_modes, figsize=(7 * n_modes, 6), squeeze=False)
    axes = axes.flatten()

    for ax_idx, (mtps_suffix, mtps_name) in enumerate(data.mtps_modes):
        ax = axes[ax_idx]
        cats = list(TRACE_CATEGORIES.keys())
        exps_plot = [e for e in data.exps if e != 'nopref']

        x = np.arange(len(cats))
        width = 0.8 / len(exps_plot)

        for idx, exp in enumerate(exps_plot):
            cat_means = []
            for cat in cats:
                cat_traces = [t for t in data.traces if get_category(t) == cat]
                speedups = [data.get_speedup(t, exp, mtps_suffix) for t in cat_traces]
                sp_vals = [s/100 + 1 for s in speedups if s is not None]
                if sp_vals:
                    gm = data.geomean(sp_vals)
                    cat_means.append((gm - 1) * 100)
                else:
                    cat_means.append(0)

            bars = ax.bar(x + idx * width, cat_means, width,
                          label=ALL_EXP_LABELS.get(exp, exp),
                          color=ALL_COLORS.get(exp, '#888'),
                          edgecolor='white', linewidth=0.5)

        ax.set_xticks(x + width * (len(exps_plot) - 1) / 2)
        ax.set_xticklabels([TRACE_CAT_NAMES[c] for c in cats], fontsize=8)
        ax.set_ylabel('Geomean Speedup (%)')
        ax.set_title(f'{mtps_name} — Category Breakdown', fontweight='bold')
        ax.axhline(y=0, color='black', linewidth=0.5)
        ax.grid(axis='y', alpha=0.3)
        ax.legend(fontsize=7, ncol=2)

    for ax_idx in range(n_modes, len(axes)):
        axes[ax_idx].set_visible(False)

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart3_category_summary.png')
    plt.close(fig)
    print(f"  Chart 3 saved: res/{OUT_PREFIX}chart3_category_summary.png")


def chart_rank_distribution(data):
    """Chart 4: Per-trace ranking distribution (how many #1, #2, etc.)."""
    fig, ax = plt.subplots(figsize=(14, 7))

    rank_counts = {e: defaultdict(int) for e in data.exps}
    for trace in data.traces:
        perf = [(e, data.get_ipc(trace, e)) for e in data.exps]
        perf = [(e, v) for e, v in perf if v is not None and v > 0]
        perf.sort(key=lambda x: x[1], reverse=True)
        for rank, (e, _) in enumerate(perf):
            rank_counts[e][rank + 1] += 1

    n_exp = len(data.exps)
    total_traces = len(data.traces)
    x = np.arange(n_exp)
    bottom = np.zeros(n_exp)
    cmap = plt.cm.RdYlGn_r

    for rank in range(1, n_exp + 1):
        values = [rank_counts[e].get(rank, 0) for e in data.exps]
        color = cmap(rank / n_exp)
        bars = ax.bar(x, values, 0.7, bottom=bottom, label=f'#{rank}',
                      color=color, edgecolor='white', linewidth=0.5)
        for i, (bar, v) in enumerate(zip(bars, values)):
            if v > 0:
                ax.text(bar.get_x() + bar.get_width()/2, bottom[i] + v/2,
                        f'{v}', ha='center', va='center', fontsize=8, fontweight='bold')
        bottom = [b + v for b, v in zip(bottom, values)]

    ax.set_xticks(x)
    ax.set_xticklabels([ALL_EXP_LABELS.get(e, e) for e in data.exps],
                       rotation=30, ha='right', fontsize=10)
    ax.set_ylabel(f'Number of Traces (total={total_traces})')
    ax.set_title('Per-Trace Performance Ranking Distribution', fontweight='bold', fontsize=14)
    ax.legend(fontsize=8, loc='upper right', ncol=3)
    ax.set_ylim(0, total_traces)

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart4_rank_distribution.png')
    plt.close(fig)
    print(f"  Chart 4 saved: res/{OUT_PREFIX}chart4_rank_distribution.png")


def chart_ipc_detail(data):
    """Chart 5: Per-trace IPC grouped, ML experiments across BW modes."""
    ml_exps = [e for e in ['pythia', 'linucb', 'tsetlin', 'meta_selector'] if e in data.exps]
    if len(ml_exps) < 2:
        return

    n_bw = len(data.mtps_modes)
    fig, ax = plt.subplots(figsize=(max(18, 2 * len(data.traces)), 8))
    x = np.arange(len(data.traces))
    width = 0.8 / len(ml_exps)

    bw_alphas = [0.9, 0.6, 0.4][:n_bw]
    from matplotlib.patches import Patch
    legend_elements = []

    for bw_idx, (mtps_suffix, mtps_name) in enumerate(data.mtps_modes):
        alpha = bw_alphas[bw_idx]
        offset = (bw_idx - (n_bw - 1) / 2) * 0.06
        for exp_idx, (exp, label) in enumerate(zip(ml_exps, [ALL_EXP_LABELS.get(e, e) for e in ml_exps])):
            vals = [data.get_ipc(t, exp) or 0 for t in data.traces]
            if mtps_suffix:
                vals2 = [data.get_ipc(t, exp + mtps_suffix) or 0 for t in data.traces]
                vals = vals2
            pos = x + (exp_idx - (len(ml_exps) - 1) / 2) * width + offset
            ax.bar(pos, vals, width * 0.9, color=ALL_COLORS.get(exp, '#888'),
                   alpha=alpha, edgecolor='black', linewidth=0.3)
            if bw_idx == 0:
                legend_elements.append(Patch(facecolor=ALL_COLORS.get(exp, '#888'),
                                             alpha=alpha, label=f'{label} {mtps_name.split("(")[0].strip()}'))

    for bw_idx in range(1, n_bw):
        _, mtps_name = data.mtps_modes[bw_idx]
        alpha = bw_alphas[bw_idx]
        legend_elements.append(Patch(facecolor='#888888', alpha=alpha,
                                      label=mtps_name.split('(')[0].strip()))

    ax.set_xticks(x)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('IPC')
    ax.set_title(f'IPC Comparison: ML Prefetchers across {n_bw} DRAM BW Modes',
                 fontweight='bold', fontsize=14)
    ax.legend(handles=legend_elements, fontsize=8, loc='upper right')
    ax.grid(axis='y', alpha=0.3)

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart5_ipc_detail.png')
    plt.close(fig)
    print(f"  Chart 5 saved: res/{OUT_PREFIX}chart5_ipc_detail.png")


# ============================================================================
# Phase 2: Prefetch Quality Charts
# ============================================================================

def chart_coverage_overprediction(data):
    """Chart 6: Coverage vs Overprediction scatter (baseline BW)."""
    fig, ax = plt.subplots(figsize=(12, 10))

    exp_list = [e for e in data.exps if e != 'nopref']
    markers = ['o', 's', 'D', '^', 'v', '<', '>', 'p', 'h', '*']
    all_coverages = []
    all_overs = []

    for idx, exp in enumerate(exp_list):
        x_vals = []
        y_vals = []
        for t in data.traces:
            cov = data.get_coverage(t, exp)
            over = data.get_overprediction(t, exp)
            if cov is not None and over is not None:
                x_vals.append(cov)
                y_vals.append(over)

        if x_vals:
            ax.scatter(x_vals, y_vals, label=ALL_EXP_LABELS.get(exp, exp),
                       color=ALL_COLORS.get(exp, '#888'),
                       marker=markers[idx % len(markers)],
                       s=80, edgecolors='black', linewidth=0.5, alpha=0.8)
            all_coverages.extend(x_vals)
            all_overs.extend(y_vals)

    # Draw iso-quality contours
    if all_coverages:
        max_val = max(max(all_coverages), max(all_overs)) * 1.1
        for quality in [0.5, 1.0, 2.0, 5.0]:
            xs = np.linspace(-10, max_val, 100)
            ys = xs / quality
            ax.plot(xs, ys, '--', color='gray', alpha=0.3, linewidth=0.5)
            ax.annotate(f'Q={quality:.1f}', (max_val * 0.85, max_val * 0.85 / quality),
                        fontsize=7, color='gray', alpha=0.7)

    ax.set_xlabel('Coverage (%) — Higher = Better')
    ax.set_ylabel('Overprediction (%) — Lower = Better')
    ax.set_title('Coverage vs Overprediction — Baseline DRAM BW\n'
                 '(Top-Left corner = optimal: high coverage, low overprediction)',
                 fontweight='bold', fontsize=13)
    ax.axhline(y=0, color='black', linewidth=0.5)
    ax.axvline(x=0, color='black', linewidth=0.5)
    ax.legend(fontsize=9, loc='best')
    ax.grid(alpha=0.3)

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart6_coverage_overprediction.png')
    plt.close(fig)
    print(f"  Chart 6 saved: res/{OUT_PREFIX}chart6_coverage_overprediction.png")


def chart_accuracy_comparison(data):
    """Chart 7: Per-trace prefetch accuracy (baseline BW)."""
    ml_exps = [e for e in data.exps if e not in ('nopref',)]
    if len(ml_exps) < 2:
        return

    fig, ax = plt.subplots(figsize=(20, 8))
    x = np.arange(len(data.traces))
    width = 0.8 / len(ml_exps)

    for idx, exp in enumerate(ml_exps):
        vals = [data.get_accuracy(t, exp) or 0 for t in data.traces]
        ax.bar(x + idx * width, vals, width,
               label=ALL_EXP_LABELS.get(exp, exp),
               color=ALL_COLORS.get(exp, '#888'),
               edgecolor='white', linewidth=0.3)

    ax.set_xticks(x + width * (len(ml_exps) - 1) / 2)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('Accuracy (useful/issued, %)')
    ax.set_title('Prefetch Accuracy by Trace — Baseline DRAM BW (higher = better)',
                 fontweight='bold', fontsize=14)
    ax.legend(fontsize=9, ncol=3)
    ax.grid(axis='y', alpha=0.3)

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart7_accuracy.png')
    plt.close(fig)
    print(f"  Chart 7 saved: res/{OUT_PREFIX}chart7_accuracy.png")


def chart_timeliness(data):
    """Chart 8: Prefetch timeliness by BW mode (ML prefetchers)."""
    ml_exps = [e for e in ['pythia', 'linucb', 'tsetlin'] if e in data.exps]
    if len(ml_exps) < 2:
        return

    n_bw = len(data.mtps_modes)
    fig, axes = plt.subplots(1, n_bw, figsize=(7 * n_bw, 7), squeeze=False)
    axes = axes.flatten()

    for ax_idx, (mtps_suffix, mtps_name) in enumerate(data.mtps_modes):
        ax = axes[ax_idx]
        x = np.arange(len(data.traces))
        width = 0.8 / len(ml_exps)

        for idx, exp in enumerate(ml_exps):
            vals = [data.get_timeliness(t, exp, mtps_suffix) or 0 for t in data.traces]
            ax.bar(x + idx * width, vals, width,
                   label=ALL_EXP_LABELS.get(exp, exp),
                   color=ALL_COLORS.get(exp, '#888'),
                   edgecolor='white', linewidth=0.3)

        ax.set_xticks(x + width * (len(ml_exps) - 1) / 2)
        ax.set_xticklabels([get_short_name(t) for t in data.traces],
                           rotation=45, ha='right', fontsize=7)
        ax.set_ylabel('Timeliness (% timely)')
        ax.set_title(f'{mtps_name}\n(higher = better)', fontweight='bold')
        ax.legend(fontsize=8)
        ax.grid(axis='y', alpha=0.3)
        ax.axhline(y=80, color='green', linewidth=0.5, linestyle='--', alpha=0.5)
        ax.axhline(y=50, color='red', linewidth=0.5, linestyle='--', alpha=0.5)

    for ax_idx in range(n_bw, len(axes)):
        axes[ax_idx].set_visible(False)

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart8_timeliness.png')
    plt.close(fig)
    print(f"  Chart 8 saved: res/{OUT_PREFIX}chart8_timeliness.png")


def chart_prefetch_volume(data):
    """Chart 9: Prefetch issued vs useful scatter (baseline BW)."""
    fig, axes = plt.subplots(1, 2, figsize=(20, 8))

    exp_list = [e for e in data.exps if e != 'nopref']
    markers = ['o', 's', 'D', '^', 'v', '<', '>', 'p', 'h']

    # Left: issued vs useful scatter
    ax = axes[0]
    for idx, exp in enumerate(exp_list):
        x_vals = []
        y_vals = []
        for t in data.traces:
            r = data.get(t, exp)
            if r:
                issued = safe_float(r, 'Core_0_L2C_prefetch_issued') / 1000
                useful = safe_float(r, 'Core_0_L2C_prefetch_useful') / 1000
                if issued > 0:
                    x_vals.append(issued)
                    y_vals.append(useful)
        if x_vals:
            ax.scatter(x_vals, y_vals, label=ALL_EXP_LABELS.get(exp, exp),
                       color=ALL_COLORS.get(exp, '#888'), s=60,
                       marker=markers[idx % len(markers)],
                       edgecolors='black', linewidth=0.3, alpha=0.7)

    max_val = max([safe_float(r, 'Core_0_L2C_prefetch_issued') / 1000 for r in data.rows], default=100)
    ax.plot([0, max_val], [0, max_val], 'k--', alpha=0.2)
    ax.set_xlabel('Prefetch Issued (thousands)')
    ax.set_ylabel('Prefetch Useful (thousands)')
    ax.set_title('Issued vs Useful Prefetches', fontweight='bold')
    ax.legend(fontsize=8)
    ax.grid(alpha=0.3)

    # Right: waste comparison
    ax = axes[1]
    x = np.arange(len(data.traces))
    width = 0.8 / len(exp_list)
    for idx, exp in enumerate(exp_list):
        vals = [data.get_waste(t, exp) or 0 for t in data.traces]
        vals_k = [v / 1000 for v in vals]
        ax.bar(x + idx * width, vals_k, width,
               label=ALL_EXP_LABELS.get(exp, exp),
               color=ALL_COLORS.get(exp, '#888'),
               edgecolor='white', linewidth=0.3)

    ax.set_xticks(x + width * (len(exp_list) - 1) / 2)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('Waste Prefetches (thousands)')
    ax.set_title('Prefetch Waste = Issued - Useful (lower = better)', fontweight='bold')
    ax.legend(fontsize=8, ncol=2)
    ax.grid(axis='y', alpha=0.3)

    fig.suptitle('Prefetch Volume Analysis — Baseline DRAM BW', fontweight='bold', fontsize=14)
    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart9_prefetch_volume.png')
    plt.close(fig)
    print(f"  Chart 9 saved: res/{OUT_PREFIX}chart9_prefetch_volume.png")


# ============================================================================
# Phase 3: MetaSelector Behavior Analysis
# ============================================================================

def chart_meta_selection_distribution(data):
    """Chart 10: MetaSelector sub-prefetcher selection distribution."""
    if 'meta_selector' not in data.exps:
        print("  Chart 10 skipped: meta_selector not in data")
        return

    fig, axes = plt.subplots(1, 2, figsize=(20, 8))

    # Left: Per-trace stacked bar chart
    ax = axes[0]
    sub_names = ['tsetlin', 'linucb', 'stride']
    sub_colors = {'tsetlin': '#a65628', 'linucb': '#984ea3', 'stride': '#4daf4a'}
    sub_labels = {'tsetlin': 'Tsetlin', 'linucb': 'LinUCB', 'stride': 'Stride'}

    x = np.arange(len(data.traces))
    bottom = np.zeros(len(data.traces))
    width = 0.7

    for sub in sub_names:
        vals = [data.get_meta_selected_pct(t, 'meta_selector', sub) or 0 for t in data.traces]
        # Also try without MTPS suffix
        vals2 = [data.get_meta_selected_pct(t, 'meta_selector_MTPS600', sub) or 0 for t in data.traces]
        # Normalize selection if count-based
        if all(v == 0 for v in vals):
            counts = [data.get_meta_selected(t, 'meta_selector', sub) or 0 for t in data.traces]
            total = sum(counts)
            if total > 0:
                vals = [c / total * 100 for c in counts]

        ax.bar(x, vals, width, bottom=bottom, label=sub_labels[sub],
               color=sub_colors[sub], edgecolor='white', linewidth=0.5)
        bottom = [b + v for b, v in zip(bottom, vals)]

    ax.set_xticks(x)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('Selection Share (%)')
    ax.set_title('MetaSelector: Sub-Prefetcher Selection Distribution', fontweight='bold')
    ax.legend(fontsize=10)
    ax.set_ylim(0, 105)

    # Right: Decision breakdown pie chart
    ax = axes[1]
    decision_stats = defaultdict(float)
    for t in data.traces:
        for stat_name in ['all_empty', 'stride_fallback', 'single_ml', 'explore', 'greedy', 'loser_boost']:
            v = data.get_meta_stat(t, 'meta_selector', stat_name)
            if v:
                decision_stats[stat_name] += v

    if sum(decision_stats.values()) > 0:
        labels = {
            'greedy': 'Greedy (sticky winner)', 'explore': 'ε-Explore',
            'stride_fallback': 'Stride Fallback', 'all_empty': 'All Empty',
            'single_ml': 'Single ML', 'loser_boost': 'Loser Boost',
        }
        colors = ['#4daf4a', '#ff7f00', '#377eb8', '#e41a1c', '#984ea3', '#a65628']
        wedges = []
        wedge_labels = []
        for i, (k, v) in enumerate(sorted(decision_stats.items(), key=lambda x: x[1], reverse=True)):
            if v > 0:
                wedges.append(v)
                wedge_labels.append(labels.get(k, k))

        if wedges:
            ax.pie(wedges, labels=wedge_labels, autopct='%1.1f%%',
                   colors=colors[:len(wedges)], startangle=90)
            ax.set_title('Decision Breakdown (Aggregate)', fontweight='bold')
        else:
            ax.text(0.5, 0.5, 'No MetaSelector decision data', ha='center', transform=ax.transAxes)
    else:
        ax.text(0.5, 0.5, 'No MetaSelector decision data', ha='center', transform=ax.transAxes)

    fig.suptitle('MetaSelector Behavior Analysis — Baseline DRAM BW',
                 fontweight='bold', fontsize=14)
    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart10_meta_selection.png')
    plt.close(fig)
    print(f"  Chart 10 saved: res/{OUT_PREFIX}chart10_meta_selection.png")


def chart_meta_confidence(data):
    """Chart 11: MetaSelector confidence/accuracy EMA values."""
    if 'meta_selector' not in data.exps:
        print("  Chart 11 skipped: meta_selector not in data")
        return

    fig, axes = plt.subplots(1, 2, figsize=(16, 7))

    sub_names = ['tsetlin', 'linucb', 'stride']
    sub_colors = {'tsetlin': '#a65628', 'linucb': '#984ea3', 'stride': '#4daf4a'}
    sub_labels = {'tsetlin': 'Tsetlin', 'linucb': 'LinUCB', 'stride': 'Stride'}

    # Left: Accuracy EMA
    ax = axes[0]
    x = np.arange(len(data.traces))
    width = 0.25
    for idx, sub in enumerate(sub_names):
        vals = [data.get_meta_stat(t, 'meta_selector', f'accuracy_ema_{sub}') or 0
                for t in data.traces]
        ax.bar(x + idx * width, vals, width, label=sub_labels[sub],
               color=sub_colors[sub], edgecolor='white', linewidth=0.3)

    ax.set_xticks(x + width)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('Accuracy EMA')
    ax.set_title('MetaSelector: Sub-Prefetcher Accuracy EMA', fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(axis='y', alpha=0.3)

    # Right: Confidence EMA
    ax = axes[1]
    for idx, sub in enumerate(sub_names):
        vals = [data.get_meta_stat(t, 'meta_selector', f'conf_ema_{sub}') or 0
                for t in data.traces]
        ax.bar(x + idx * width, vals, width, label=sub_labels[sub],
               color=sub_colors[sub], edgecolor='white', linewidth=0.3)

    ax.set_xticks(x + width)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('Confidence EMA')
    ax.set_title('MetaSelector: Sub-Prefetcher Confidence EMA', fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(axis='y', alpha=0.3)

    fig.suptitle('MetaSelector Confidence Analysis — Baseline DRAM BW',
                 fontweight='bold', fontsize=14)
    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart11_meta_confidence.png')
    plt.close(fig)
    print(f"  Chart 11 saved: res/{OUT_PREFIX}chart11_meta_confidence.png")


# ============================================================================
# Phase 4: Ablation Analysis
# ============================================================================

def chart_ablation_waterfall(data):
    """Chart 12: Ablation waterfall — component contribution."""
    if not data.ablation_exps:
        print("  Chart 12 skipped: no ablation experiments in data")
        return

    # Base vs ablation pairs
    pairs = [
        ('linucb', 'linucb_no_dyn_deg', 'LinUCB\nDynamic Degree'),
        ('tsetlin', 'tsetlin_no_dyn_deg', 'Tsetlin\nDynamic Degree'),
        ('linucb', 'linucb_no_featurewise', 'LinUCB\nFeature-wise'),
        ('tsetlin', 'tsetlin_no_featurewise', 'Tsetlin\nFeature-wise'),
        ('meta_selector', 'meta_selector_no_explore', 'MetaSelector\nε-Explore'),
        ('linucb', 'linucb_no_suppress', 'LinUCB\nSuppress Gating'),
    ]

    valid_pairs = []
    for base, abl, label in pairs:
        if base in data.exps or any(r['Exp'] == base for r in data.rows if safe_float(r, 'Core_0_IPC') > 0):
            valid_pairs.append((base, abl, label))

    # Remove pairs where ablation data is missing
    valid_pairs = [(b, a, l) for b, a, l in valid_pairs
                   if any(r['Exp'] == a for r in data.rows)]

    if not valid_pairs:
        print("  Chart 12 skipped: no valid ablation pairs")
        return

    fig, ax = plt.subplots(figsize=(12, 7))

    y_labels = []
    deltas = []
    colors_waterfall = []

    for base, abl, label in valid_pairs:
        base_speedups = []
        abl_speedups = []
        for t in data.traces:
            b_sp = data.get_speedup(t, base)
            a_sp = data.get_speedup(t, abl)
            if b_sp is not None and a_sp is not None:
                base_speedups.append(b_sp)
                abl_speedups.append(a_sp)

        if base_speedups and abl_speedups:
            base_geomean = data.geomean([s/100 + 1 for s in base_speedups])
            abl_geomean = data.geomean([s/100 + 1 for s in abl_speedups])
            base_gm_pct = (base_geomean - 1) * 100
            abl_gm_pct = (abl_geomean - 1) * 100
            delta = base_gm_pct - abl_gm_pct

            y_labels.append(label)
            deltas.append(delta)
            colors_waterfall.append('#e41a1c' if delta > 0 else '#4daf4a')

    if not deltas:
        print("  Chart 12 skipped: no ablation delta data")
        return

    y_pos = range(len(y_labels))
    bars = ax.barh(y_pos, deltas, color=colors_waterfall, edgecolor='black', linewidth=0.5)
    ax.set_yticks(y_pos)
    ax.set_yticklabels(y_labels, fontsize=11)
    ax.set_xlabel('Speedup Loss (pp) — Larger = Component More Important')
    ax.set_title('Ablation Analysis: Component Contribution\n'
                 '(Speedup drop when component is disabled)',
                 fontweight='bold', fontsize=14)
    ax.axvline(x=0, color='black', linewidth=0.5)
    ax.grid(axis='x', alpha=0.3)

    for bar, delta in zip(bars, deltas):
        ax.text(bar.get_width() + 0.1, bar.get_y() + bar.get_height()/2,
                f'-{delta:.1f}pp', va='center', fontsize=10, fontweight='bold',
                color='#e41a1c' if delta > 0 else '#4daf4a')

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart12_ablation_waterfall.png')
    plt.close(fig)
    print(f"  Chart 12 saved: res/{OUT_PREFIX}chart12_ablation_waterfall.png")


def chart_ablation_detail(data):
    """Chart 13: Per-trace ablation delta heatmap."""
    if not data.ablation_exps:
        return

    pairs = [
        ('linucb', 'linucb_no_dyn_deg', 'LinUCB DynDeg'),
        ('tsetlin', 'tsetlin_no_dyn_deg', 'Tsetlin DynDeg'),
        ('linucb', 'linucb_no_featurewise', 'LinUCB FeatWise'),
        ('tsetlin', 'tsetlin_no_featurewise', 'Tsetlin FeatWise'),
        ('meta_selector', 'meta_selector_no_explore', 'MetaSel Explore'),
    ]

    valid_pairs = []
    heatmap_data = []
    pair_labels = []

    for base, abl, label in pairs:
        exists = any(r['Exp'] == abl for r in data.rows)
        if not exists:
            continue

        row = []
        for t in data.traces:
            b_ipc = data.get_ipc(t, base)
            a_ipc = data.get_ipc(t, abl)
            if b_ipc and a_ipc and b_ipc > 0:
                delta = (b_ipc - a_ipc) / b_ipc * 100  # % loss
            else:
                delta = 0
            row.append(delta)
        heatmap_data.append(row)
        pair_labels.append(label)

    if not heatmap_data:
        return

    data_arr = np.array(heatmap_data)
    fig, ax = plt.subplots(figsize=(22, max(4, 1.2 * len(pair_labels))))
    im = ax.imshow(data_arr, cmap='YlOrRd', aspect='auto', vmin=-5, vmax=15)

    ax.set_xticks(range(len(data.traces)))
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_yticks(range(len(pair_labels)))
    ax.set_yticklabels(pair_labels, fontsize=11)
    ax.set_title('Ablation Impact: IPC Loss (%) when Component Disabled\n'
                 '(Red = Larger loss = More important component)',
                 fontweight='bold', fontsize=14)

    for i in range(len(pair_labels)):
        for j in range(len(data.traces)):
            v = data_arr[i, j]
            color = 'white' if v > 8 else 'black'
            ax.text(j, i, f'{v:.1f}', ha='center', va='center',
                    fontsize=7, color=color, fontweight='bold')

    cbar = plt.colorbar(im, ax=ax, shrink=0.8)
    cbar.set_label('IPC Loss (%)')

    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart13_ablation_detail.png')
    plt.close(fig)
    print(f"  Chart 13 saved: res/{OUT_PREFIX}chart13_ablation_detail.png")


# ============================================================================
# Phase 2e: Cache Behavior
# ============================================================================

def chart_cache_behavior(data):
    """Chart 14: LLC miss rate and L2C hit rate comparison."""
    fig, axes = plt.subplots(1, 2, figsize=(20, 8))

    exp_list = [e for e in data.exps if e != 'nopref']

    # Left: LLC load miss
    ax = axes[0]
    x = np.arange(len(data.traces))
    width = 0.8 / len(exp_list)
    for idx, exp in enumerate(exp_list):
        vals = [data.get_llc_miss(t, exp) or 0 for t in data.traces]
        vals_k = [v / 1000 for v in vals]
        ax.bar(x + idx * width, vals_k, width,
               label=ALL_EXP_LABELS.get(exp, exp),
               color=ALL_COLORS.get(exp, '#888'),
               edgecolor='white', linewidth=0.2)

    ax.set_xticks(x + width * (len(exp_list) - 1) / 2)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('LLC Load Misses (thousands)')
    ax.set_title('LLC Load Misses — Baseline BW (lower = better)', fontweight='bold')
    ax.legend(fontsize=7, ncol=2)
    ax.grid(axis='y', alpha=0.3)

    # Right: L2C load miss
    ax = axes[1]
    for idx, exp in enumerate(exp_list):
        vals = [data.get_l2c_miss(t, exp) or 0 for t in data.traces]
        vals_k = [v / 1000 for v in vals]
        ax.bar(x + idx * width, vals_k, width,
               label=ALL_EXP_LABELS.get(exp, exp),
               color=ALL_COLORS.get(exp, '#888'),
               edgecolor='white', linewidth=0.2)

    ax.set_xticks(x + width * (len(exp_list) - 1) / 2)
    ax.set_xticklabels([get_short_name(t) for t in data.traces],
                       rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('L2C Load Misses (thousands)')
    ax.set_title('L2C Load Misses — Baseline BW (lower = better)', fontweight='bold')
    ax.legend(fontsize=7, ncol=2)
    ax.grid(axis='y', alpha=0.3)

    fig.suptitle('Cache Behavior Analysis — Baseline DRAM BW', fontweight='bold', fontsize=14)
    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart14_cache_behavior.png')
    plt.close(fig)
    print(f"  Chart 14 saved: res/{OUT_PREFIX}chart14_cache_behavior.png")


# ============================================================================
# Radar Chart
# ============================================================================

def chart_radar(data):
    """Chart 15: Multi-dimensional radar comparison."""
    ml_compare = [e for e in ['pythia', 'linucb', 'tsetlin'] if e in data.exps]
    if len(ml_compare) < 3:
        print("  Chart 15 skipped: need >=3 ML experiments")
        return

    metrics_radar = ['IPC', 'Accuracy', 'Coverage', 'Timeliness', 'Low Waste']
    ml_labels_r = [ALL_EXP_LABELS.get(e, e) for e in ml_compare]
    ml_colors_r = [ALL_COLORS.get(e, '#888') for e in ml_compare]

    def compute_radar_scores(mtps_suffix):
        scores = {exp: [0.0] * len(metrics_radar) for exp in ml_compare}
        n_traces = 0
        for trace in data.traces:
            all_ipcs = {}
            all_accs = {}
            all_covs = {}
            all_times = {}
            all_wastes = {}

            for exp in ml_compare:
                ipc = data.get_ipc(trace, exp) if not mtps_suffix else data.get_ipc(trace, exp + mtps_suffix)
                acc = data.get_accuracy(trace, exp, mtps_suffix)
                cov = data.get_coverage(trace, exp, mtps_suffix)
                tim = data.get_timeliness(trace, exp, mtps_suffix)
                wst = data.get_waste(trace, exp, mtps_suffix)

                if ipc and ipc > 0:
                    all_ipcs[exp] = ipc
                    all_accs[exp] = acc or 0
                    all_covs[exp] = cov or 0
                    all_times[exp] = tim or 0
                    all_wastes[exp] = wst or 0

            if len(all_ipcs) < len(ml_compare):
                continue
            n_traces += 1

            for metric_idx, (vals, higher_better) in enumerate([
                (all_ipcs, True), (all_accs, True), (all_covs, True),
                (all_times, True), (all_wastes, False),
            ]):
                best = max(vals.values())
                worst = min(vals.values())
                rng = best - worst if best != worst else 1.0
                for exp in ml_compare:
                    if higher_better:
                        scores[exp][metric_idx] += (vals[exp] - worst) / rng
                    else:
                        scores[exp][metric_idx] += (best - vals[exp]) / rng

        if n_traces > 0:
            for e in ml_compare:
                scores[e] = [s / n_traces for s in scores[e]]
        return scores

    n_bw = len(data.mtps_modes)
    fig, axes = plt.subplots(1, n_bw, figsize=(6.5 * n_bw, 6.5),
                             subplot_kw=dict(polar=True), squeeze=False)
    axes = axes.flatten()

    angles = np.linspace(0, 2 * np.pi, len(metrics_radar), endpoint=False).tolist()
    angles += angles[:1]

    for ax_idx, (mtps_suffix, mtps_name) in enumerate(data.mtps_modes):
        ax = axes[ax_idx]
        scores = compute_radar_scores(mtps_suffix)

        for exp, label, color in zip(ml_compare, ml_labels_r, ml_colors_r):
            values = scores[exp] + scores[exp][:1]
            ax.plot(angles, values, 'o-', linewidth=2, label=label, color=color, markersize=5)
            ax.fill(angles, values, alpha=0.1, color=color)

        ax.set_xticks(angles[:-1])
        ax.set_xticklabels(metrics_radar, fontsize=9)
        ax.set_ylim(0, 1.0)
        ax.set_yticks([0.2, 0.4, 0.6, 0.8, 1.0])
        ax.set_yticklabels(['0.2', '0.4', '0.6', '0.8', '1.0'], fontsize=7)
        ax.set_title(mtps_name.split('(')[0].strip(), fontweight='bold', fontsize=12, pad=20)
        ax.legend(loc='upper right', bbox_to_anchor=(1.35, 1.1), fontsize=9)

    for ax_idx in range(n_bw, len(axes)):
        axes[ax_idx].set_visible(False)

    fig.suptitle('Multi-Dimensional Comparison (Radar) — Higher = Better',
                 fontweight='bold', fontsize=14)
    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart15_radar.png')
    plt.close(fig)
    print(f"  Chart 15 saved: res/{OUT_PREFIX}chart15_radar.png")


# ============================================================================
# Summary Table
# ============================================================================

def chart_summary_table(data):
    """Chart 16: Summary statistics table."""
    fig, ax = plt.subplots(figsize=(18, max(3, 0.55 * len(data.exps))))
    ax.axis('off')

    stats = {}
    for exp in data.exps:
        speedups = []
        accs = []
        times = []
        ipcs_s = []
        for mtps_suffix, _ in data.mtps_modes:
            for trace in data.traces:
                sp = data.get_speedup(trace, exp, mtps_suffix)
                acc = data.get_accuracy(trace, exp, mtps_suffix)
                tim = data.get_timeliness(trace, exp, mtps_suffix)
                ipc = data.get_ipc(trace, exp) if not mtps_suffix else data.get_ipc(trace, exp + mtps_suffix)

                if sp is not None: speedups.append(sp)
                if acc is not None and acc >= 0: accs.append(acc)
                if tim is not None and tim >= 0: times.append(tim)
                if ipc is not None and ipc > 0: ipcs_s.append(ipc)

        stats[exp] = {
            'avg_ipc': np.mean(ipcs_s) if ipcs_s else 0,
            'avg_speedup': np.mean(speedups) if speedups else 0,
            'geomean_speedup': (data.geomean([s/100 + 1 for s in speedups]) - 1) * 100 if speedups else 0,
            'avg_acc': np.mean(accs) if accs else 0,
            'avg_timeliness': np.mean(times) if times else 0,
            'pos_traces': sum(1 for s in speedups if s > 0),
            'total': len(speedups),
            'wins': sum(1 for t in data.traces
                        if data.get_ipc(t, exp) and all(
                            data.get_ipc(t, exp) >= (data.get_ipc(t, oe) or 0)
                            for oe in data.exps if oe != exp)),
        }

    col_labels = ['Algorithm', 'Avg IPC', 'Avg Speedup',
                  'Geomean Speedup', 'Accuracy', 'Timeliness',
                  'Pos/Tot', '#1 Wins']
    table_data = []
    for e in data.exps:
        s = stats[e]
        table_data.append([
            ALL_EXP_LABELS.get(e, e),
            f'{s["avg_ipc"]:.4f}',
            f'{s["avg_speedup"]:+.1f}%',
            f'{s["geomean_speedup"]:+.1f}%',
            f'{s["avg_acc"]:.1f}%',
            f'{s["avg_timeliness"]:.1f}%',
            f'{s["pos_traces"]}/{s["total"]}',
            f'{s["wins"]}',
        ])

    table = ax.table(cellText=table_data, colLabels=col_labels,
                     cellLoc='center', loc='center')
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1.0, 1.8)

    # Highlight ML rows
    for exp_name in ('pythia', 'linucb', 'tsetlin', 'meta_selector'):
        if exp_name in data.exps:
            row_idx = data.exps.index(exp_name) + 1
            for j in range(len(col_labels)):
                table[row_idx, j].set_facecolor(
                    '#ffecd0' if exp_name == 'pythia' else
                    '#e8d5f0' if exp_name == 'linucb' else
                    '#f5e6d3' if exp_name == 'tsetlin' else '#ffe0e0')

    fig.suptitle(f'Overall Summary ({len(data.traces)} traces × {len(data.mtps_modes)} BW modes)',
                 fontweight='bold', fontsize=14)
    fig.tight_layout()
    fig.savefig(f'res/{OUT_PREFIX}chart16_summary_table.png')
    plt.close(fig)
    print(f"  Chart 16 saved: res/{OUT_PREFIX}chart16_summary_table.png")


# ============================================================================
# Statistical Tests
# ============================================================================

def print_statistical_tests(data):
    """Print statistical comparisons between key prefetchers."""
    ml_exps = [e for e in ['pythia', 'linucb', 'tsetlin', 'meta_selector'] if e in data.exps]
    if len(ml_exps) < 2:
        return

    print("\n" + "=" * 80)
    print(" Statistical Analysis")
    print("=" * 80)

    # Win/Tie/Loss table
    for exp_a in ml_exps:
        for exp_b in ml_exps:
            if exp_a >= exp_b:
                continue
            wins_a = 0
            wins_b = 0
            ties = 0
            ipc_pairs = []
            for t in data.traces:
                ipc_a = data.get_ipc(t, exp_a)
                ipc_b = data.get_ipc(t, exp_b)
                if ipc_a and ipc_b and ipc_a > 0 and ipc_b > 0:
                    ipc_pairs.append((ipc_a, ipc_b))
                    if ipc_a > ipc_b * 1.01:
                        wins_a += 1
                    elif ipc_b > ipc_a * 1.01:
                        wins_b += 1
                    else:
                        ties += 1

            total = wins_a + wins_b + ties
            if total == 0:
                continue

            label_a = ALL_EXP_LABELS.get(exp_a, exp_a)
            label_b = ALL_EXP_LABELS.get(exp_b, exp_b)

            # Paired t-test
            t_stat_val = float('nan')
            p_val_val = float('nan')
            sig = 'N/A'
            if HAS_SCIPY and len(ipc_pairs) >= 5:
                diffs = [a - b for a, b in ipc_pairs]
                t_stat_val, p_val_val = scipy_stats.ttest_1samp(diffs, 0)
                sig = '***' if p_val_val < 0.001 else '**' if p_val_val < 0.01 else '*' if p_val_val < 0.05 else 'ns'

            print(f"  {label_a:>12} vs {label_b:<12}  "
                  f"Win: {wins_a:>2}  Tie: {ties:>2}  Loss: {wins_b:<2}  "
                  f"(t={t_stat_val:+.2f}, p={p_val_val:.4f} {sig})")

    # Category breakdown
    print("\n  --- Category Geomean Speedup ---")
    for cat in ['A', 'B', 'C', 'D']:
        cat_traces = [t for t in data.traces if get_category(t) == cat]
        line = f"  {TRACE_CAT_NAMES[cat]:>25s}:  "
        for exp in ml_exps:
            vals = [data.get_speedup(t, exp) for t in cat_traces]
            vals = [v for v in vals if v is not None]
            if vals:
                gm = data.geomean([v/100 + 1 for v in vals])
                line += f"{ALL_EXP_LABELS.get(exp, exp):>6s}={(gm-1)*100:+.1f}%  "
            else:
                line += f"{ALL_EXP_LABELS.get(exp, exp):>6s}=N/A       "
        print(line)


# ============================================================================
# Main
# ============================================================================

def main():
    global OUT_PREFIX

    parser = argparse.ArgumentParser(description='Pythia Complete Experiment Analysis')
    parser.add_argument('--csv', type=str, default=None,
                        help='Path to rollup CSV (default: auto-detect)')
    parser.add_argument('--csv4c', type=str, default=None,
                        help='Path to 4C rollup CSV')
    parser.add_argument('--out', type=str, default='res',
                        help='Output directory for charts (default: res/)')
    parser.add_argument('--prefix', type=str, default=None,
                        help='Output filename prefix')
    parser.add_argument('--no-4c', action='store_true',
                        help='Skip 4C analysis')
    parser.add_argument('--skip-phase', type=int, nargs='+', default=[],
                        help='Skip specific phases (1-4)')
    args = parser.parse_args()

    # Auto-detect CSV
    if args.csv is None:
        candidates = [
            'experiments/course_1C_results.csv',
            'res/course_1C_results.csv',
        ]
        for c in candidates:
            if os.path.exists(c):
                args.csv = c
                break
        if args.csv is None:
            print("ERROR: No CSV found. Use --csv to specify path.")
            sys.exit(1)

    if not os.path.exists(args.csv):
        print(f"ERROR: CSV not found: {args.csv}")
        sys.exit(1)

    csv_stem = os.path.splitext(os.path.basename(args.csv))[0]
    if args.prefix:
        OUT_PREFIX = args.prefix + '_'
    else:
        OUT_PREFIX = csv_stem + '_'

    os.makedirs(args.out, exist_ok=True)

    print(f"Loading: {args.csv}")
    rows, header = load_csv(args.csv)
    print(f"  Loaded {len(rows)} rows, {len(header)} columns")
    print(f"  Columns: {header[:5]}... (total {len(header)})")

    data = ExperimentData(rows)
    print(f"  Detected {len(data.traces)} traces")
    print(f"  Detected experiments: {data.exps}")
    print(f"  Detected BW modes: {[m[1] for m in data.mtps_modes]}")
    if data.ablation_exps:
        print(f"  Detected ablation experiments: {data.ablation_exps}")

    setup_plots()

    # Phase 1: Performance comparison
    if 1 not in args.skip_phase:
        print("\n--- Phase 1: Performance Comparison ---")
        chart_speedup_overall(data)
        chart_speedup_heatmap(data)
        chart_category_summary(data)
        chart_rank_distribution(data)
        chart_ipc_detail(data)

    # Phase 2: Prefetch quality
    if 2 not in args.skip_phase:
        print("\n--- Phase 2: Prefetch Quality Analysis ---")
        chart_coverage_overprediction(data)
        chart_accuracy_comparison(data)
        chart_timeliness(data)
        chart_prefetch_volume(data)
        chart_cache_behavior(data)

    # Phase 3: MetaSelector behavior
    if 3 not in args.skip_phase:
        print("\n--- Phase 3: MetaSelector Behavior Analysis ---")
        chart_meta_selection_distribution(data)
        chart_meta_confidence(data)

    # Phase 4: Ablation
    if 4 not in args.skip_phase:
        print("\n--- Phase 4: Ablation Analysis ---")
        chart_ablation_waterfall(data)
        chart_ablation_detail(data)

    # Multi-dimensional radar
    print("\n--- Multi-Dimensional Comparison ---")
    chart_radar(data)

    # Summary table
    print("\n--- Summary ---")
    chart_summary_table(data)

    # Statistical tests
    print_statistical_tests(data)

    # List all generated files
    print(f"\n{'=' * 60}")
    print(f" All charts generated in {args.out}/")
    generated = sorted([f for f in os.listdir(args.out) if f.startswith(OUT_PREFIX)])
    for i, name in enumerate(generated, 1):
        print(f"  {i:>2}. {name}")
    print(f"Total: {len(generated)} charts")
    print(f"{'=' * 60}")


if __name__ == '__main__':
    main()
