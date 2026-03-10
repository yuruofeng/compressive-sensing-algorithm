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
- [⚙️ 环境要求](#️-环境要求)
- [🤝 贡献指南](#-贡献指南)
- [📚 参考文献](#-参考文献)
- [📝 更新日志](#-更新日志)

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
│   │   ├── 📁 +greedy/              # 贪婪算法
│   │   │   ├── 📄 OMP.m             # 正交匹配追踪 ✨
│   │   │   └── 📄 MFOCUSS.m         # 多测量 FOCUSS
│   │   │
│   │   ├── 📁 +iterative/           # 迭代阈值算法 ✨
│   │   │   ├── 📄 IHT.m             # 迭代硬阈值
│   │   │   └── 📄 FISTA.m           # 快速迭代软阈值
│   │   │
│   │   └── 📁 +probabilistic/       # 概率推断算法 ✨
│   │       └── 📄 AMP.m             # 近似消息传递
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
│   ├── 📁 核心框架
│   │   ├── 📄 AlgorithmRegistry.m   # 算法注册中心
│   │   ├── 📄 DemoConfig.m          # 参数配置类
│   │   ├── 📄 ResultPresenter.m     # 结果展示器
│   │   └── 📄 demo_unified.m        # 统一入口 ✨
│   │
│   ├── 📁 专用演示
│   │   ├── 📄 demo_bcs.m            # 贝叶斯压缩感知
│   │   ├── 📄 demo_mmv.m            # 多测量向量
│   │   └── 📄 demo_block_sparse.m   # 块稀疏信号
│   │
│   └── 📁 工具
│       └── 📄 run_all_demos.m       # 批量测试
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
|   **OMP**   | `cs.algorithms.greedy.OMP`     | 通用稀疏重构  | 经典贪婪算法 |
| **MFOCUSS** | `cs.algorithms.greedy.MFOCUSS` | 多测量 FOCUSS | p-范数正则化 |

### 🔄 迭代阈值算法 ✨

|     算法     | 类路径                             | 适用场景       | 特点              |
| :----------: | ---------------------------------- | -------------- | ----------------- |
| **IHT** | `cs.algorithms.iterative.IHT`   | 大规模问题     | 计算效率高        |
| **FISTA** | `cs.algorithms.iterative.FISTA` | LASSO 问题     | O(1/k²) 收敛速度 |

### 📨 概率推断算法 ✨

|    算法    | 类路径                                 | 适用场景     | 特点         |
| :--------: | -------------------------------------- | ------------ | ------------ |
| **AMP** | `cs.algorithms.probabilistic.AMP` | 大规模稀疏重构 | 理论保证完善 |

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

### 🔹 OMP 正交匹配追踪 ✨

```matlab
setup();

% 准备数据
A = randn(128, 256);
x_true = zeros(256, 1);
x_true(randperm(256, 20)) = randn(20, 1);
b = A * x_true + 0.01 * randn(128, 1);

% 配置并运行 OMP
opts = cs.core.Options('MaxIterations', 50, 'Verbose', true);
alg = cs.algorithms.greedy.OMP('Sparsity', 20, opts);
[result, info] = alg.solve(A, b);

% 输出结果
fprintf('🔄 迭代次数: %d\n', info.iterations);
fprintf('📍 支撑集大小: %d\n', info.support_size);
fprintf('📏 残差范数: %.2e\n', info.residual_norm);

metrics = result.evaluate(x_true);
fprintf('📈 重构 SNR: %.2f dB\n', metrics.SNR);
```

### 🔹 FISTA 快速迭代软阈值 ✨

```matlab
setup();

% 准备数据
A = randn(128, 256);
x_true = zeros(256, 1);
x_true(randperm(256, 20)) = randn(20, 1);
b = A * x_true + 0.01 * randn(128, 1);

% 配置并运行 FISTA
opts = cs.core.Options('MaxIterations', 300, 'Verbose', true);
alg = cs.algorithms.iterative.FISTA('Lambda', 0.01, opts);
[result, info] = alg.solve(A, b);

% 输出结果
fprintf('🔄 迭代次数: %d\n', info.iterations);
fprintf('📊 Lambda: %.4f\n', info.lambda);
fprintf('📈 收敛: %s\n', string(info.converged));

metrics = result.evaluate(x_true);
fprintf('📏 重构 SNR: %.2f dB\n', metrics.SNR);
```

### 🔹 统一演示系统 ✨

本工具箱提供统一的算法演示接口，支持灵活的参数配置和标准化的结果展示。

#### 基本用法

```matlab
% 运行所有算法
demo_unified();

% 指定算法运行
demo_unified('Algorithms', {'OMP', 'IHT', 'FISTA'});

% 按类别运行
demo_unified('Category', 'greedy');

% 自定义参数
demo_unified('N', 512, 'K', 50, 'M', 200, 'NoiseLevel', 0.05);

% 使用预设配置
demo_unified('Preset', 'high_sparsity');

% 生成测试报告
demo_unified('GenerateReport', true);
```

#### 可用预设配置

| 预设名称 | 信号长度 | 稀疏度 | 测量数 | 噪声水平 | 适用场景 |
|---------|---------|-------|-------|---------|---------|
| `standard` | 256 | 20 | 128 | 0.01 | 标准测试 |
| `high_sparsity` | 512 | 100 | 256 | 0.01 | 高稀疏度场景 |
| `low_measurements` | 256 | 20 | 64 | 0.01 | 低测量数场景 |
| `noisy` | 256 | 20 | 128 | 0.1 | 高噪声环境 |
| `clean` | 256 | 20 | 128 | 0.0 | 无噪声环境 |

#### 专用演示脚本

```matlab
% 贝叶斯压缩感知专用演示
demo_bcs();

% 多测量向量(MMV)问题演示
demo_mmv();

% 块稀疏信号重构演示
demo_block_sparse();
```

#### 批量测试

```matlab
% 运行所有demo并生成测试报告
results = run_all_demos();
```

#### 扩展开发

**添加新算法到演示系统**：

1. 在 `AlgorithmRegistry.m` 中注册算法：
```matlab
obj.registerAlgorithm('MyAlgo', 'custom', @cs.algorithms.custom.MyAlgo, ...
    'Description', '我的算法描述', ...
    'DefaultParams', struct('param1', 10), ...
    'Reference', '参考文献');
```

2. 在demo中使用：
```matlab
demo_unified('Algorithms', {'MyAlgo', 'OMP'});
```

**添加新的预设配置**：

在 `DemoConfig.m` 的 `createPresets` 方法中添加：
```matlab
presets.my_custom = struct(...
    'N', 1024, 'K', 100, 'M', 400, ...
    'noiseLevel', 0.05, 'randomSeed', 123);
```

#### Demo系统架构

```
demos/
├── 核心框架
│   ├── AlgorithmRegistry.m    # 算法注册中心
│   ├── DemoConfig.m           # 参数配置类
│   ├── ResultPresenter.m      # 结果展示器
│   └── demo_unified.m         # 统一入口
│
├── 专用演示
│   ├── demo_bcs.m             # BCS专用
│   ├── demo_mmv.m             # MMV专用
│   └── demo_block_sparse.m    # 块稀疏专用
│
└── 工具
    └── run_all_demos.m        # 批量测试
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

## 🤝 贡献指南

欢迎对本项目做出贡献！

### 如何贡献

1. **Fork 本仓库**
   ```bash
   git clone https://github.com/yuruofeng/compressive-sensing-algorithm.git
   ```

2. **创建特性分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **编写代码**
   - 遵循现有代码风格
   - 添加必要的注释和文档
   - 编写单元测试

4. **提交更改**
   ```bash
   git commit -m "Add: 描述你的更改"
   ```

5. **推送分支**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **创建 Pull Request**

### 代码规范

- 使用 MATLAB 命名空间组织代码
- 所有算法继承自 `cs.core.Algorithm` 基类
- 函数和类需要包含完整的注释文档
- 添加输入验证和错误处理

### 添加新算法

1. 在对应子目录下创建算法类文件
2. 继承 `cs.core.Algorithm` 抽象基类
3. 实现所有必需的抽象方法
4. 在 `demos/AlgorithmRegistry.m` 中注册
5. 编写测试用例
6. 更新文档

---

## 📚 参考文献

### 稀疏贝叶斯学习
- Tipping, M. E. (2001). "Sparse Bayesian Learning and the Relevance Vector Machine." *Journal of Machine Learning Research*
- Zhang, Z., & Rao, B. D. (2013). "Sparse Signal Recovery With Temporally Correlated Source Vectors Using Sparse Bayesian Learning." *IEEE Journal of Selected Topics in Signal Processing*

### 贪婪算法
- Tropp, J. A., & Gilbert, A. C. (2007). "Signal Recovery From Random Measurements Via Orthogonal Matching Pursuit." *IEEE Transactions on Information Theory*

### 迭代阈值算法
- Blumensath, T., & Davies, M. E. (2009). "Iterative Hard Thresholding for Compressed Sensing." *Applied and Computational Harmonic Analysis*
- Beck, A., & Teboulle, M. (2009). "A Fast Iterative Shrinkage-Thresholding Algorithm for Linear Inverse Problems." *SIAM Journal on Imaging Sciences*

### 概率推断算法
- Donoho, D. L., Maleki, A., & Montanari, A. (2009). "Message-Passing Algorithms for Compressed Sensing." *Proceedings of the National Academy of Sciences*

---

## 📝 更新日志

### v2.0.0 (2026-03-10)

#### ✨ 新增功能
- 🎯 统一演示系统框架（`demo_unified.m`）
- 📋 算法注册中心（`AlgorithmRegistry.m`）
- ⚙️ 参数配置系统（`DemoConfig.m`）
- 📊 结果展示器（`ResultPresenter.m`）
- 🔄 迭代阈值算法：IHT、FISTA
- 🎯 贪婪算法：OMP
- 📨 概率推断算法：AMP

#### 🔧 优化改进
- 📚 重构demo目录结构
- 🧹 清理冗余文档和代码
- 📖 更新和完善文档

#### 🐛 问题修复
- 修复算法参数解析问题
- 修复AMP算法数值稳定性
- 修复矩阵维度不匹配问题

---

## 📄 许可证

本项目仅供学术研究和教学使用。

---

<p align="center">
  <i>🔬 压缩感知工具箱 - 高效的稀疏信号重构解决方案</i>
</p>
