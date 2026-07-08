# 多层自适应数据预取系统

> GitHub 仓库：[https://github.com/yuruop/Pythia](https://github.com/yuruop/Pythia)

本项目是**计算机体系结构课程实验**，基于开源 ChampSim 模拟器框架 [Pythia](https://github.com/ChampSim/Pythia)，实现了三种硬件数据预取器（Tsetlin Machine、LinUCB Bandit、Stride）及一个**元层智能选择器（MetaSelector）**，构建了"硬件层多预取器池 + 元层实时调度"的分层自适应数据预取系统。元层选择器在每次访存请求时实时评估各子预取器的表现，通过粘性贪婪 + Epsilon 退火策略选出最优预取输出，在多个 SPEC2006/CloudSuite/Ligra 测试程序上实现了最高 56.6% 的 IPC 提升。详细设计见 [方案设计/多层自适应数据预取系统设计方案.md](方案设计/多层自适应数据预取系统设计方案.md)。

---

## 项目结构

```
Pythia/
├── README.md                          # 本文件
├── LICENSE / LICENSE.champsim         # 开源许可
├── CITATION.cff                       # 引用信息
├── Makefile                           # 编译入口
├── build_champsim.sh                  # 构建脚本（单核）
├── build_champsim_highcore.sh         # 构建脚本（多核 4+）
├── setvars.sh                         # 环境变量初始化
│
├── .devcontainer/                     # ★ VS Code Dev Container 配置
│   ├── devcontainer.json              # 容器定义（自动安装依赖 + 编译 libbf）
│   └── Dockerfile                     # Ubuntu 22.04 + CUDA 12.4 + g++/cmake/perl
│
├── inc/                               # C++ 头文件
│   ├── meta_selector.h                # ★ 元层选择器类定义
│   ├── tsetlin.h                      # ★ Tsetlin Machine 预取器
│   ├── linucb.h                       # ★ LinUCB Bandit 预取器
│   ├── stride.h                       # Stride 预取器
│   └── champsim.h / ...               # ChampSim 框架头文件
│
├── prefetcher/                        # 预取器实现 + ChampSim 包装器
│   ├── meta_selector.cc               # ★ 元层选择器实现（~527 行）
│   ├── meta_selector.l2c_pref         # ★ 独立元层选择器 L2C 包装
│   ├── multi.l2c_pref                 # ★ 多预取器集成 L2C 包装
│   ├── tsetlin.cc / tsetlin.l2c_pref  # ★ Tsetlin 预取器
│   ├── linucb.cc / linucb.l2c_pref    # ★ LinUCB 预取器
│   └── stride.cc / ...                # Stride 及其他预取器
│
├── config/                            # 配置文件（.ini）
│   ├── meta_selector.ini              # 元层选择器参数
│   ├── tsetlin.ini                    # Tsetlin 参数
│   ├── linucb.ini                     # LinUCB 参数
│   ├── pythia.ini / nopref.ini 等     # 基准预取器配置
│   └── *_no_*.ini                     # 消融实验配置
│
├── src/                               # ChampSim 框架源码
│   └── knobs.cc                       # Knob 变量注册与 INI 解析
│
├── branch/                            # 分支预测器
├── replacement/                       # Cache 替换策略
├── TsetlinMachine/                    # Tsetlin Machine 库
├── libbf/                             # Bloom Filter 库（容器自动克隆编译）
│
├── experiments/                       # ★ 实验脚本与数据
│   ├── course_1C.exp                  # 单核课程实验矩阵
│   ├── course_4C.exp                  # 四核课程实验矩阵
│   ├── course_1C.tlist / course_4C.tlist  # Trace 列表
│   ├── analyze_all.py                 # ★ 完整分析脚本（16 张图表 + 统计检验）
│   ├── run_course_1C.sh               # 1C 自动运行脚本（420 jobs）
│   ├── rollup_1C_base_config.exp      # Rollup 实验定义（1C）
│   ├── rollup_1C_base_config.mfile    # Rollup 指标定义（1C）
│   ├── rollup_4C_base_config.mfile    # Rollup 指标定义（4C）
│   └── course_1C_results.csv          # 示例结果文件
│
├── scripts/                           # 工具脚本
│   ├── download_traces.pl             # Trace 下载脚本（断点续传 + MD5 校验）
│   ├── create_jobfile.pl              # 任务文件生成
│   ├── rollup.py                      # CSV 数据合并（Python 版）
│   ├── rollup.pl                      # CSV 数据合并（Perl 版）
│   └── artifact_traces.csv / .md5     # Trace URL 索引与 MD5 值
│
├── res/                               # 分析结果输出（图表 .png）
├── bin/                               # 编译产物
├── obj/                               # 中间编译文件
│
└── 方案设计/
    └── 多层自适应数据预取系统设计方案.md  # ★ 核心设计文档
```

**★** 标记为本课程的核心贡献文件。

---

## 环境部署

### 前置要求

1. **VS Code** + [Dev Containers 扩展](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. **Docker Desktop**
3. NVIDIA GPU + Container Toolkit（可选，仅 GPU 加速需要）

### 启动步骤

```bash
# 1. 用 VS Code 打开项目
code Pythia/

# 2. VS Code 会提示 "Reopen in Container"，点击确认
#    或按 F1 → 输入 "Dev Containers: Reopen in Container"
```

容器启动后会自动：
- 安装 g++、cmake、perl、wget 等依赖
- 克隆并编译 `libbf`（Bloom Filter 库）
- 配置 `PYTHIA_HOME` 环境变量

进入容器后在 VS Code 终端验证：

```bash
echo $PYTHIA_HOME    # 应输出 /workspace
g++ --version         # 确认编译器可用
```

---

## 运行实验

### 第一步：编译 ChampSim 模拟器

构建不同预取器对应的 ChampSim 二进制：

```bash
cd /workspace
source setvars.sh

# ===== 单核二进制（用于 course_1C.exp）=====
# NoPref（无预取基线）
./build_champsim.sh no no no 1

# SPP / Bingo / MLOP 基线
./build_champsim.sh no spp_dev2 no 1
./build_champsim.sh no bingo no 1
./build_champsim.sh no mlop no 1

# Pythia（原始 RL 预取器）
./build_champsim.sh no scooby no 1

# 本课程实现的预取器
./build_champsim.sh no linucb no 1
./build_champsim.sh no tsetlin no 1
./build_champsim.sh multi multi no 1    # MetaSelector（集成版）

# ===== 四核二进制（用于 course_4C.exp）=====
./build_champsim.sh no no no 4
./build_champsim.sh no spp_dev2 no 4
./build_champsim.sh no bingo no 4
./build_champsim.sh no mlop no 4
./build_champsim.sh no scooby no 4
./build_champsim.sh no linucb no 4
./build_champsim.sh no tsetlin no 4
./build_champsim.sh multi multi no 4

# ================建议只编译================
后续测试全部用这两个即可
./build_champsim.sh multi multi no 1
./build_champsim.sh multi multi no 4

```

编译产物位于 `bin/` 目录，命名格式为 `{分支预测器}-{L1D}-{L2C}-{LLC}-{替换}-{核心数}core`，例如 `bin/perceptron-multi-multi-no-ship-1core`。

> **参数说明**：`build_champsim.sh` 接受 4 个参数 — `[L1D预取器] [L2C预取器] [LLC预取器] [核心数]`。`multi` 代表包含 MetaSelector、Tsetlin、LinUCB 的多预取器集成版。

### 第二步：准备测试 Trace 数据

课程实验需要 20 条 trace，按来源分为三类：

| 类别 | 数量 | 获取方式 | 大小 |
|------|:---:|------|------|
| SPEC2006（标准） | 12 条 | 自动下载脚本 | ~3 GB |
| **Ligra + PARSEC** | 4 条 | **手动下载**（Zenodo） | ~8 GB |
| **CloudSuite**（cassandra/nutch/streaming） | 3 条 | **仓库已包含**（`traces/`） | ~170 MB |

> 注：CloudSuite 的 3 条 trace 因网络原因难以自动下载，已直接放在仓库的 `traces/` 目录中，clone 后即可使用。

#### A. 自动下载 SPEC trace（12 条）

下载脚本支持**断点续传**和 **MD5 完整性校验**：

```bash
cd /workspace

# 创建存放目录
mkdir -p traces/ligra traces/parsec2.1

# 自动下载脚本可获取的 trace
perl scripts/download_traces.pl \
    --csv scripts/artifact_traces.csv \
    --tlist-dir experiments \
    --dir traces \
    --jobs 4
```

> `--tlist-dir experiments` 会扫描 `experiments/` 下所有 `.tlist` 文件，自动提取需要的 trace 列表，只下载缺失的文件。

#### B. 手动下载 Ligra 与 PARSEC trace（4 条）

这两组 trace 体积较大，需从 Zenodo 手动下载：

- **Ligra**（3 条：BFS / PageRank / Triangle）：https://doi.org/10.5281/zenodo.14267977
- **PARSEC 2.1**（1 条：canneal / streamcluster）：https://doi.org/10.5281/zenodo.14268118

下载后放入对应目录：

```bash
# Ligra trace 放入 traces/ligra/
# PARSEC trace 放入 traces/parsec2.1/
# 路径需与 course_1C.tlist / course_4C.tlist 中的 TRACE= 路径匹配
```

打开 Zenodo 链接后，直接点击 **Download as ZIP** 下载整个数据集，解压后将 `.champsimtrace.xz` 文件复制到上述目录即可。

#### C. CloudSuite trace（仓库已包含）

`cassandra_phase0_core0.trace.xz`、`nutch_phase0_core0.trace.xz`、`streaming_phase0_core1.trace.xz` 已放在仓库 `traces/` 目录下，无需额外下载。

### 第三步：生成并运行实验（单核 1C）

实验的核心流程是：用 `create_jobfile.pl` 将 **trace 定义（`.tlist`）+ 实验参数（`.exp`）** 展开为 ChampSim 命令行，然后批量执行。

```bash
# 进入实验目录（以下所有路径统一使用 $PYTHIA_HOME）
cd $PYTHIA_HOME/experiments

# 生成 course_1C 的全部任务脚本（--local 1 表示本机运行，--ncores 20 控制并发数）
perl $PYTHIA_HOME/scripts/create_jobfile.pl \
  --exe $PYTHIA_HOME/bin/perceptron-multi-multi-no-ship-1core \
  --tlist $PYTHIA_HOME/experiments/course_1C.tlist \
  --exp $PYTHIA_HOME/experiments/course_1C.exp \
  --local 1 --ncores 20 > run_course_1C.sh

# 执行（将在 experiments/ 目录下生成大量 .out 文件）
bash run_course_1C.sh
```

**`create_jobfile.pl` 参数说明**：

| 参数 | 说明 |
|------|------|
| `--exe` | ChampSim 可执行文件完整路径（`multi` 构建 = 内置全部预取器，运行时通过 `--l2c_prefetcher_types` 切换） |
| `--tlist` | Trace 定义文件（每一段定义 `NAME`、`TRACE` 路径、`KNOBS`） |
| `--exp` | 实验定义文件（定义 `BASE` 模拟参数 + 各预取器变量 + 实验组合） |
| `--local` | `1` = 本机并行运行（`xargs -P`）；`0` = 生成 Slurm `sbatch` 脚本 |
| `--ncores` | 本机并行任务数（建议设为 CPU 核心数，最多 20） |

`course_1C.exp` 定义了 **8 种预取器 × 3 种 DRAM 带宽**（600/2400/4800 MTPS）共 24 组实验配置，每条 trace 跑 24 组 = 20 条 trace × 24 组 = **480 个任务**。每个任务结束会生成 `{trace名}_{实验名}.out`。

> 完整运行约需 **4-8 小时**（取决于 CPU 核数）。建议先用 2-3 条 trace 做快速验证：
> ```bash
> # 从 course_1C.tlist 中挑少量 trace 生成快速测试
> head -20 $PYTHIA_HOME/experiments/course_1C.tlist > $PYTHIA_HOME/experiments/quick.tlist
> perl $PYTHIA_HOME/scripts/create_jobfile.pl \
>   --exe $PYTHIA_HOME/bin/perceptron-multi-multi-no-ship-1core \
>   --tlist $PYTHIA_HOME/experiments/quick.tlist \
>   --exp $PYTHIA_HOME/experiments/course_1C.exp \
>   --local 1 --ncores 8 > run_quick.sh
> bash run_quick.sh
> ```

### 第四步：汇总数据（Rollup）

所有任务跑完后，用 `rollup.pl` 将散落在各个 `.out` 文件中的关键指标汇总为一张结构化 CSV：

```bash
cd $PYTHIA_HOME/experiments

# 汇总 course_1C 结果（--ext out 指定输出文件扩展名）
perl $PYTHIA_HOME/scripts/rollup.pl \
  --tlist $PYTHIA_HOME/experiments/course_1C.tlist \
  --exp $PYTHIA_HOME/experiments/course_1C.exp \
  --mfile $PYTHIA_HOME/experiments/rollup_1C_base_config.mfile \
  --ext out > $PYTHIA_HOME/res/course_1C_results.csv
```

**参数说明**：

| 参数 | 说明 |
|------|------|
| `--tlist` | Trace 定义文件（与运行实验时一致） |
| `--exp` | 实验定义文件（与运行实验时一致） |
| `--mfile` | Metric 定义文件：指定从 `.out` 中提取哪些统计指标（IPC、预取量、MetaSelector 决策分布等）及聚合方式 |
| `--ext` | 输出文件的扩展名（默认为 `txt`，若运行时没加 `> xxx.out` 则需调整） |

> 仓库同时提供了 Python 版 `scripts/rollup.py`，用法类似：
> ```bash
> python $PYTHIA_HOME/scripts/rollup.py \
>   --tlist $PYTHIA_HOME/experiments/course_1C.tlist \
>   --exp $PYTHIA_HOME/experiments/course_1C.exp \
>   --mfile $PYTHIA_HOME/experiments/rollup_1C_base_config.mfile \
>   -o $PYTHIA_HOME/res/course_1C_results.csv
> ```

输出的 CSV 格式如下（每行 = 一条 trace × 一组实验配置）：

| Trace | Exp | Core_0_IPC | Core_0_L2C_prefetch_issued | ... |
|-------|-----|-----------|---------------------------|-----|
| 462.libquantum-1343B | nopref | 0.362 | 0 | ... |
| 462.libquantum-1343B | meta_selector | 0.566 | 82345 | ... |
| ... | ... | ... | ... | ... |

### 第五步：分析结果

```bash
cd $PYTHIA_HOME

# 生成完整分析报告（16 张图表 + 统计检验）
python $PYTHIA_HOME/experiments/analyze_all.py \
    --csv $PYTHIA_HOME/res/course_1C_results.csv \
    --out $PYTHIA_HOME/res/
```

运行结束后，`res/` 目录下生成以下文件：

| 编号 | 文件 | 内容 |
|------|------|------|
| 1 | `*_chart1_speedup_overall.png` | 各预取器平均 IPC Speedup（分组柱状图） |
| 2 | `*_chart2_heatmap.png` | 逐 Trace IPC Speedup 热力图 |
| 3 | `*_chart3_category_summary.png` | 按 Trace 类别的几何平均 Speedup |
| 4 | `*_chart4_rank_distribution.png` | 排名分布统计 |
| 5 | `*_chart5_ipc_detail.png` | ML 预取器逐 Trace IPC 对比 |
| 6 | `*_chart6_coverage_overprediction.png` | Coverage vs Overprediction 散点图 |
| 7 | `*_chart7_accuracy.png` | 预取准确率对比 |
| 8 | `*_chart8_timeliness.png` | 预取及时性（Timely/Late） |
| 9 | `*_chart9_prefetch_volume.png` | 预取量分析（Issued/Useful/Waste） |
| 10 | `*_chart10_meta_selection.png` | MetaSelector 子预取器选择分布 + 决策饼图 |
| 11 | `*_chart11_meta_confidence.png` | MetaSelector Accuracy/Confidence EMA |
| 12 | `*_chart12_ablation_waterfall.png` | 消融实验瀑布图（组件贡献量化） |
| 13 | `*_chart13_ablation_detail.png` | 消融实验逐 Trace 热力图 |
| 14 | `*_chart14_cache_behavior.png` | LLC Miss 与 L2C Miss 对比 |
| 15 | `*_chart15_radar.png` | 多维度雷达图 |
| 16 | `*_chart16_summary_table.png` | 汇总统计表 |

同时终端输出**配对 t 检验**的 Win/Tie/Loss 分析和分类别 Speedup 汇总。

---

### 四核实验（4C）

流程与 1C 完全一致，仅需替换对应的 `.tlist`、`.exp`、`--exe` 和 `--mfile`：

```bash
# 1. 生成四核任务
cd $PYTHIA_HOME/experiments
perl $PYTHIA_HOME/scripts/create_jobfile.pl \
  --exe $PYTHIA_HOME/bin/perceptron-multi-multi-no-ship-4core \
  --tlist $PYTHIA_HOME/experiments/course_4C.tlist \
  --exp $PYTHIA_HOME/experiments/course_4C.exp \
  --local 1 --ncores 10 > run_course_4C.sh

# 2. 运行
bash run_course_4C.sh

# 3. 汇总
perl $PYTHIA_HOME/scripts/rollup.pl \
  --tlist $PYTHIA_HOME/experiments/course_4C.tlist \
  --exp $PYTHIA_HOME/experiments/course_4C.exp \
  --mfile $PYTHIA_HOME/experiments/rollup_4C_base_config.mfile \
  --ext out > $PYTHIA_HOME/res/course_4C_results.csv

# 4. 分析（合并 1C + 4C）
python $PYTHIA_HOME/experiments/analyze_all.py \
    --csv $PYTHIA_HOME/res/course_1C_results.csv \
    --csv4c $PYTHIA_HOME/res/course_4C_results.csv \
    --out $PYTHIA_HOME/res/
```

---

## 实验信息

| 项目 | 单核 (1C) | 四核 (4C) |
|------|----------|----------|
| 实验文件 | `course_1C.exp` | `course_4C.exp` |
| Trace 文件 | `course_1C.tlist` (20 条) | `course_4C.tlist` (20 条) |
| 预取器 | 8 种 | 8 种 |
| DRAM 带宽 | 3 种 (600 / 2400 / 4800 MTPS) | 1 种 (2400 MTPS) |
| 总任务数 | 420 | 160 |
| Warmup | 20M 指令 | 20M 指令 |
| Simulation | 100M 指令 | 100M 指令 |

---

## 关键成果

- **IPC Speedup**：MetaSelector 在 462.libquantum 上达到 **+56.6%** 的 IPC 提升
- **存储开销**：全系统额外约 **~96 KB**（Tsetlin ~39 KB + LinUCB ~46 KB + Stride ~3 KB + MetaSelector ~8 KB）
- **纳秒级响应**：子预取器推断与元层选择均在单周期硬件时延约束内

---

## 致谢

本项目基于：

- [Pythia](https://github.com/ChampSim/Pythia) — ChampSim-based prefetcher framework (MICRO 2021)
- [ChampSim](https://github.com/ChampSim/ChampSim) — Trace-driven microarchitecture simulator
- [Tsetlin Machine](https://github.com/cair/TsetlinMachine) — Low-complexity pattern recognition

感谢课程指导老师与助教的支持！
