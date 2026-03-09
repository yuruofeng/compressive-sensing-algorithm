# 压缩感知算法库 v2.0.0

## 项目结构

```
压缩感知/
├── +cs/                          # 主包命名空间
│   ├── +core/                    # 核心抽象层
│   │   ├── Algorithm.m          # 算法抽象基类
│   │   ├── Options.m            # 统一配置类
│   │   ├── Result.m             # 结果封装类
│   │   └── ConvergenceChecker.m # 收敛检查器
│   ├── +algorithms/              # 算法实现
│   │   ├── +sbl/                # 稀疏贝叶斯学习
│   │   │   ├── BSBL.m          # 块稀疏SBL
│   │   │   ├── TMSBL.m         # 时间相关MMV-SBL
│   │   │   └── MSBL.m          # 多测量SBL
│   │   ├── +convex/             # 凸优化方法
│   │   │   ├── LassoADMM.m     # LASSO-ADMM
│   │   │   └── BasisPursuit.m  # 基追踪
│   │   └── +greedy/             # 贪婪算法
│   │       └── MFOCUSS.m       # 多测量FOCUSS
│   ├── +data/                    # 数据封装
│   │   ├── SensorMatrix.m       # 感知矩阵
│   │   ├── BlockStructure.m     # 块结构
│   │   └── IterationHistory.m   # 迭代历史
│   ├── +exceptions/              # 异常处理
│   │   ├── CSException.m
│   │   ├── InvalidInputException.m
│   │   ├── DimensionMismatchException.m
│   │   └── ConvergenceException.m
│   └── +utils/                   # 工具函数
│       ├── shrinkage.m
│       ├── lambdaLearning.m
│       └── validation.m
├── tests/                        # 测试套件
│   └── TestCSLibrary.m
├── demos/                        # 演示脚本
│   └── new/
│       └── demo_basic.m
├── docs/                         # 文档
│   └── README_v2.md
├── _archived_legacy/             # 归档旧代码
└── setup.m                       # 初始化脚本
```

## 快速开始

```matlab
% 1. 初始化
setup();

% 2. 创建测试数据
A = cs.data.SensorMatrix.random(128, 256);
x_true = zeros(256, 1);
x_true(randperm(256, 20)) = randn(20, 1);
b = A.multiply(x_true) + 0.01*randn(128, 1);

% 3. 使用BSBL算法
opts = cs.core.Options('MaxIterations', 200, 'Verbose', true);
alg = cs.algorithms.sbl.BSBL(opts);
blockStruct = cs.data.BlockStructure.equalBlock(256, 8);
[result, info] = alg.solve(A, b, blockStruct);

% 4. 评估结果
metrics = result.evaluate(x_true);
fprintf('SNR: %.2f dB\n', metrics.SNR);

% 5. 可视化
result.plotSignal('TrueSignal', x_true);
result.plotConvergence();
```

## 可用算法

| 算法 | 类名 | 用途 |
|------|------|------|
| BSBL | cs.algorithms.sbl.BSBL | 块稀疏信号重构 |
| TMSBL | cs.algorithms.sbl.TMSBL | 时间相关MMV问题 |
| MSBL | cs.algorithms.sbl.MSBL | 标准MMV问题 |
| LassoADMM | cs.algorithms.convex.LassoADMM | LASSO回归 |
| BasisPursuit | cs.algorithms.convex.BasisPursuit | 基追踪/去噪 |
| MFOCUSS | cs.algorithms.greedy.MFOCUSS | 多测量FOCUSS |

## 运行测试

```matlab
results = runtests('TestCSLibrary');
```

## 版本信息

- **版本**: 2.0.0
- **MATLAB要求**: R2016b+
- **依赖**: 无外部依赖
