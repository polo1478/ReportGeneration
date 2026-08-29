# Pharma Process Twin Report Demo

一个零第三方 Julia 依赖的可复现 Demo：模拟虚构的带夹套、完全混合批式反应器 A → B，运行基础验证和夹套温度敏感性分析，并用 Quarto 生成内部 HTML 报告。

> 所有参数和结果均为教学用途的虚构值，不能用于工艺、GMP、批次放行或监管决策。

## 前置条件

- Julia 1.12 或更新版本
- Quarto 1.7 或更新版本，用于 HTML 报告
- 若需要 PDF：额外安装 LaTeX 发行版（例如执行 `quarto install tinytex`）

## 一条命令构建

在 PowerShell 中从项目根目录运行：

```powershell
.\scripts\build_report.ps1
```

它会依次：

1. 运行 `scripts/run_all.jl`，写入 CSV、SVG、摘要和运行清单；
2. 运行 `test/runtests.jl`；
3. 渲染 `report/internal_report.qmd`；
4. 输出 `report/_output/internal_report.html` 和 `report/_output/internal_report.docx`。

需要 PDF 时运行：

```powershell
.\scripts\build_report.ps1 -Pdf
```

## 不通过 Quarto 的快速检查

```powershell
julia --project=. scripts/run_all.jl
julia --project=. test/runtests.jl
```

## 迁移到新项目

保留报告层和可追溯性文件，替换 `src/` 模型、`configs/` 工况以及 `docs/` 中的模型卡、方程登记表和来源登记表。详细清单在 [docs/migration_guide.md](docs/migration_guide.md)。

## 用 Codex 继续扩展

建议先让 Codex 只做审计，再让它修改代码：

```text
阅读 src/、configs/、docs/model_card.md 与 docs/equation_register.md。
不要改代码。列出：模型方程到 Julia 函数的映射、未定义单位、
不受来源支持的参数、缺少的验证测试，以及任何超出适用范围的结论。
不要编造文献、实验、批次数据或验证结果。
```

项目级规则位于 [AGENTS.md](AGENTS.md)。

