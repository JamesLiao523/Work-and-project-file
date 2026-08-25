import pandas as pd
from pathlib import Path
paths = [
    Path(r'c:\Users\j4a3m\OneDrive\文件\GitHub\Work-and-project-file\Project\1. Quant Project\Quantitative Risk\Portfolio_weight.csv'),
    Path(r'c:\Users\j4a3m\OneDrive\文件\GitHub\Work-and-project-file\Project\1. Quant Project\Quantitative Risk\ls_portfolio_weights.csv'),
]
for path in paths:
    df = pd.read_csv(path)
    print(f'\nFILE {path.name}')
    print('shape=', df.shape)
    print('columns first 10=', list(df.columns[:10]))
    print('first row first 10 values=', df.iloc[0, :10].tolist())
    print(df.head(2).to_string(index=False))
