f=open('main.qml','r',encoding='utf-8')
lines=f.readlines()
f.close()
depth=0
for i,line in enumerate(lines,1):
    for ch in line:
        if ch=='{': depth+=1
        elif ch=='}': depth-=1
    if depth<0:
        print(f'❌ Depth negative at line {i}: {line.strip()[:80]}')
        break
print(f'Final depth: {depth}')
if depth==0:
    print('✅ Perfectly balanced!')
elif depth>0:
    print(f'Missing {depth} closing braces')
else:
    print(f'Extra {abs(depth)} closing braces')
