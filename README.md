# Image Processing Filter
2021 ICD Project – Digital IC Design<br>
Mutual work with Jason Muliawan (NTUEE, B07901114)<br>
The project description is in `1092_ICD_P.pdf`.<br>
The original project files are in `1092_ICD_Project.zip`.
The `.zip` file is provided by Prof. Lu, which is not uploaded to this repo.<br>

## Contributions
- Chien-Kai Ma
  - OFF, PO debug
  - WO implementation
- Jason Muliawan
  - OFF, PO implementation
  - Synthesis and APR
  - Final report

## Final result
The score and rank is determined by the rules in `1092_ICD_P.pdf`.<br>
| APR Area | APR Cycle | APR Time | Area * Time | Score | Rank | Description                                                           |
| -------- | --------- | -------- | ----------- | ----- | ---- | --------------------------------------------------------------------- |
| 139721   | 30        | 524701   | 73311748421 | 10    | 16   | Our implementation                                                    |
| 119340   | 4         | 65629    | 7832164860  | 22    | 5    | Shortest APR cycle by [konosuba-lin](https://github.com/konosuba-lin) |
| 50942    | 4.5       | 75497    | 3845968174  | 30    | 1    | Best AT value & Best APR area                                         |

## Suggestions for improvement
- Save only the offset value in use to reduce redundant conditional statements
- Add registers (e.g. the first address of LCU) to reduce address calculation
- Simplify the design of the circuit
