# 🔬 压缩感知工具箱

> 基于 MATLAB 的压缩感知信号重构工具集，提供稀疏贝叶斯学习、凸优化及贪婪算法的统一实现框架

---

## 📖 目录

- [✨ 特性概览](#-特性概览)
- [🏗️ 项目结构](#️-项目结构)
- [🚀 快速开始](#-快速开始)
- [📊 算法总览](#-算法总览)
- [💡 使用示例](#-使用示例)
- [🧪 测试与验证](#-测试与验证)
- [📚 参考文献](#-参考文献)
- [⚙️ 环境要求](#️-环境要求)

---

## ✨ 特性概览

|          特性          | 描述                                 |
| :--------------------: | ------------------------------------ |
|  🎯**统一接口**  | 所有算法继承自抽象基类，调用方式一致 |
|  🔧**灵活配置**  | 支持参数预设、回调函数和自定义配置   |
|  📈**收敛追踪**  | 内置迭代历史记录和收敛性检查机制     |
|   🎨**可视化**   | 提供信号对比、收敛曲线等绘图功能     |
| ⚠️**异常处理** | 完善的异常类型体系和错误信息         |
|   🧩**模块化**   | 清晰的命名空间划分，便于扩展         |

---

## 🏗️ 项目结构

```
compressive-sensing-algorithm/
│
├── 📁 +cs/                          # 主包命名空间
│   ├── 📁 +core/                    # 核心抽象层
│   │   ├── 📄 Algorithm.m           # 算法抽象基类
│   │   ├── 📄 Options.m             # 统一配置类
│   │   ├── 📄 Result.m              # 结果封装类
│   │   └── 📄 ConvergenceChecker.m  # 收敛检查器
│   │
│   ├── 📁 +algorithms/              # 算法实现层
│   │   ├── 📁 +sbl/                 # 稀疏贝叶斯学习
│   │   │   ├── 📄 BCS.m             # 贝叶斯压缩感知
│   │   │   ├── 📄 BSBL.m            # 块稀疏 SBL
│   │   │   ├── 📄 TMSBL.m           # 时间相关 MMV-SBL
│   │   │   └── 📄 MSBL.m            # 多测量 SBL
│   │   │
│   │   ├── 📁 +convex/              # 凸优化方法
│   │   │   ├── 📄 LassoADMM.m       # LASSO-ADMM
│   │   │   └── 📄 BasisPursuit.m    # 基追踪
│   │   │
│   │   └── 📁 +greedy/              # 贪婪算法
│   │       └── 📄 MFOCUSS.m         # 多测量 FOCUSS
│   │
│   ├── 📁 +data/                    # 数据封装层
│   │   ├── 📄 SensorMatrix.m        # 感知矩阵
│   │   ├── 📄 BlockStructure.m      # 块结构定义
│   │   └── 📄 IterationHistory.m    # 迭代历史
│   │
│   ├── 📁 +exceptions/              # 异常处理层
│   │   ├── 📄 CSException.m         # 基础异常
│   │   ├── 📄 InvalidInputException.m
│   │   ├── 📄 DimensionMismatchException.m
│   │   └── 📄 ConvergenceException.m
│   │
│   └── 📁 +utils/                   # 工具函数
│       ├── 📄 shrinkage.m           # 收缩算子
│       ├── 📄 lambdaLearning.m      # 正则化参数学习
│       └── 📄 validation.m          # 输入验证
│
├── 📁 tests/                        # 测试套件
│   └── 📄 TestCSLibrary.m
│
├── 📁 demos/                        # 演示脚本
│   ├── 📄 demo_basic_usage.m
│   ├── 📄 demo_bcs.m
│   ├── 📄 demo_algorithm_comparison.m
│   ├── 📄 demo_block_sparse.m
│   └── 📄 demo_mmv.m
│
└── 📄 setup.m                       # 初始化脚本
```

---

## 🚀 快速开始

### 步骤 1️⃣ - 初始化环境

```matlab
setup();
```

### 步骤 2️⃣ - 生成测试数据

```matlab
% 创建随机感知矩阵
A = cs.data.SensorMatrix.random(128, 256);

% 生成稀疏信号 (稀疏度 K=20)
x_true = zeros(256, 1);
x_true(randperm(256, 20)) = randn(20, 1);

% 获取含噪测量
b = A.multiply(x_true) + 0.01 * randn(128, 1);
```

### 步骤 3️⃣ - 执行信号重构

```matlab
% 配置算法参数
opts = cs.core.Options('MaxIterations', 200, 'Verbose', true);

% 创建算法实例
alg = cs.algorithms.sbl.BSBL(opts);

% 定义块结构并求解
blockStruct = cs.data.BlockStructure.equalBlock(256, 8);
[result, info] = alg.solve(A, b, blockStruct);
```

### 步骤 4️⃣ - 评估与可视化

```matlab
% 计算性能指标
metrics = result.evaluate(x_true);
fprintf('📊 SNR: %.2f dB | NMSE: %.2e\n', metrics.SNR, metrics.NMSE);

% 可视化结果
result.plotSignal('TrueSignal', x_true);
result.plotConvergence();
```

---

## 📊 算法总览

### 🧠 稀疏贝叶斯学习 (SBL)

|      算法      | 类路径                      | 适用场景     | 特点           |
| :-------------: | --------------------------- | ------------ | -------------- |
|  **BCS**  | `cs.algorithms.sbl.BCS`   | 单向量重构   | RVM 快速边际化 |
| **BSBL** | `cs.algorithms.sbl.BSBL`  | 块稀疏信号   | 利用块结构先验 |
| **MSBL** | `cs.algorithms.sbl.MSBL`  | MMV 问题     | 多测量联合重构 |
| **TMSBL** | `cs.algorithms.sbl.TMSBL` | 时间相关 MMV | 时间相关性建模 |

### 📐 凸优化方法

|          算法          | 类路径                                | 适用场景    | 特点        |
| :--------------------: | ------------------------------------- | ----------- | ----------- |
|  **LassoADMM**  | `cs.algorithms.convex.LassoADMM`    | LASSO 回归  | ADMM 求解器 |
| **BasisPursuit** | `cs.algorithms.convex.BasisPursuit` | 基追踪/去噪 | 内点法实现  |

### 🎯 贪婪算法

|       算法       | 类路径                           | 适用场景      | 特点         |
| :---------------: | -------------------------------- | ------------- | ------------ |
| **MFOCUSS** | `cs.algorithms.greedy.MFOCUSS` | 多测量 FOCUSS | p-范数正则化 |

---

## 💡 使用示例

### 🔹 BCS 贝叶斯压缩感知

```matlab
setup();

% 准备数据
A = cs.data.SensorMatrix.random(128, 256);
x_true = zeros(256, 1);
x_true(randperm(256, 20)) = randn(20, 1);
b = A.multiply(x_true) + 0.01 * randn(128, 1);

% 配置并运行 BCS
opts = cs.core.Options('MaxIterations', 300, 'Tolerance', 1e-6);
alg = cs.algorithms.sbl.BCS(opts);
[result, info] = alg.solve(A, b);

% 输出结果
fprintf('🔄 迭代次数: %d\n', result.Iterations);
fprintf('🔊 估计噪声方差: %.2e\n', info.noise_variance);
fprintf('📏 支撑集大小: %d\n', info.support_size);

metrics = result.evaluate(x_true);
fprintf('📈 重构 SNR: %.2f dB\n', metrics.SNR);
```

### 🔹 多算法性能对比

```matlab
% 运行演示脚本
run('demos/demo_algorithm_comparison.m');
```

---

## 🧪 测试与验证

### 运行完整测试套件

```matlab
results = runtests('TestCSLibrary');
disp(table(results.Passed, results.Failed, results.Duration));
```

### 运行单个测试

```matlab
testCase = TestCSLibrary;
testCase.testBCSBasic();
testCase.testBSBLBasic();
testCase.testMSBLBasic();
```

---

## ⚙️ 环境要求

|         项目         | 要求              |
| :------------------: | ----------------- |
| 🖥️**MATLAB** | R2016b 或更高版本 |
| 📦**外部依赖** | 无                |
| 💾**存储空间** | ~5 MB             |

---

## 📄 许可证

本项目仅供学术研究和教学使用。

---

<p align="center">
  <i>🔬 压缩感知工具箱 - 高效的稀疏信号重构解决方案</i>
</p>
