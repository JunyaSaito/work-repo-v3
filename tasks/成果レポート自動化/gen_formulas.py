import sys, json

n = int(sys.argv[1])
months = sys.argv[2:]
FIRST = 10

def sumifs(agg_col, row):
    return (
        f"=SUMIFS('配信実績'!${agg_col}$2:${agg_col},"
        f"'配信実績'!$B$2:$B,\">=\"&$F{row},"
        f"'配信実績'!$B$2:$B,\"<\"&EDATE($F{row},1))"
    )

values = []
for i, ym in enumerate(months):
    y, m = ym.split('/')
    r = FIRST + i
    values.append([
        f"=DATE({y},{m},1)",
        sumifs('C', r), sumifs('D', r),
        f"=IFERROR(H{r}/G{r},0)",
        sumifs('E', r),
        f"=IFERROR(J{r}/H{r},0)",
        sumifs('F', r),
        f"=IFERROR(L{r}/J{r},0)",
        sumifs('G', r),
    ])

print(json.dumps({"values": values}))
