#!/usr/bin/env bash
# Runs the calculator via python3, reading params from AGENTA_TOOL_PARAMS.
exec /usr/bin/env python3 - <<'PYEOF'
import json,os,ast,operator
p=json.loads(os.environ.get('AGENTA_TOOL_PARAMS') or '{}')
expr=p.get('expression','')
ops={ast.Add:operator.add,ast.Sub:operator.sub,ast.Mult:operator.mul,ast.Div:operator.truediv,ast.Pow:operator.pow,ast.Mod:operator.mod,ast.USub:operator.neg,ast.UAdd:operator.pos,ast.FloorDiv:operator.floordiv}
def ev(node):
 if isinstance(node,ast.Constant) and isinstance(node.value,(int,float)): return node.value
 if isinstance(node,ast.BinOp): return ops[type(node.op)](ev(node.left),ev(node.right))
 if isinstance(node,ast.UnaryOp): return ops[type(node.op)](ev(node.operand))
 raise ValueError('unsupported expression')
try:
 tree=ast.parse(expr,mode='eval')
 result=ev(tree.body)
 print(json.dumps({'result':result}))
except Exception as e:
 print(json.dumps({'error':str(e)}))
 raise SystemExit(1)
PYEOF
