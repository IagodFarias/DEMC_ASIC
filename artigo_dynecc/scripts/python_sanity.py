#!/usr/bin/env python3
"""Pure Python functional self-check for independent encoding of both code formats.
No RTL simulator, no ASIC power estimate. Exercises the algebraic codeword construction.
"""
import random

def decode(cw,tbec):
 bits=[(cw>>(31-i))&1 for i in range(32)]
 a=[[bits[b+4*j] for j in range(4)] for b in range(4)]
 lin=[[a[b][j]^a[b][j+2]^bits[24+2*b+j] for j in range(2)] for b in range(4)]
 sd=[a[0][0]^a[1][1]^a[2][0]^a[3][1]^bits[16],
     a[0][1]^a[1][0]^a[2][1]^a[3][0]^bits[18],
     a[0][2]^a[1][3]^a[2][2]^a[3][3]^bits[19],
     a[0][3]^a[1][2]^a[2][3]^a[3][2]^bits[17]]
 if tbec:
  sp=[a[0][0]^a[0][1]^a[1][0]^a[1][1]^bits[20],
      a[2][0]^a[2][1]^a[3][0]^a[3][1]^bits[22],
      a[0][2]^a[0][3]^a[1][2]^a[1][3]^bits[23],
      a[2][2]^a[2][3]^a[3][2]^a[3][3]^bits[21]]
 else:
  sp=[a[0][j]^a[1][j]^a[2][j]^a[3][j]^bits[[20,22,23,21][j]] for j in range(4)]
 sumsl=sum(sum(v) for v in lin)
 if ((any(sp) and any(sd)) or sumsl>1) and (not tbec or not(sum(sd)==0 and sum(sp)==1 and sumsl>=2)):
  q1=sp[0]+sp[1]+sd[0]+sd[1]
  q2=sp[2]+sp[3]+sd[2]+sd[3]
  if q1>q2:
   for b in range(4):
    for j in range(2):a[b][j]^=lin[b][j]
  elif q1<q2:
   for b in range(4):
    for j in range(2):a[b][j+2]^=lin[b][j]
  elif any((sp[0],sp[1],sd[0],sd[1])):
   for b in range(4):
    a[b][1]^=lin[b][1];a[b][2]^=lin[b][0]
 return sum(a[b][j]<<(15-(b*4+j)) for b in range(4) for j in range(4))

def encode(word,tbec):
 s=[[(word>>(15-(i*4+j)))&1 for j in range(4)] for i in range(4)]
 d=[s[0][0]^s[1][1]^s[2][0]^s[3][1], s[0][1]^s[1][0]^s[2][1]^s[3][0],
    s[0][2]^s[1][3]^s[2][2]^s[3][3], s[0][3]^s[1][2]^s[2][3]^s[3][2]]
 if tbec:
  p=[s[0][0]^s[0][1]^s[1][0]^s[1][1],s[2][0]^s[2][1]^s[3][0]^s[3][1],
     s[0][2]^s[0][3]^s[1][2]^s[1][3],s[2][2]^s[2][3]^s[3][2]^s[3][3]]
 else:
  p=[s[0][j]^s[1][j]^s[2][j]^s[3][j] for j in range(4)]
 cb=[s[i][j]^s[i][j+2] for i in range(4) for j in range(2)]
 bits=[s[i][j] for j in range(4) for i in range(4)]+[d[k] for k in (0,3,1,2)]+[p[k] for k in (0,3,1,2)]+cb
 assert len(bits)==32
 return sum(bit<<(31-i) for i,bit in enumerate(bits))

if __name__=='__main__':
 rng=random.Random(20261021)
 mismatch=0
 for i in range(10000):
  word=rng.randrange(1<<16)
  a,b=encode(word,True),encode(word,False)
  assert a>>16==b>>16
  assert decode(a,True)==word
  assert decode(b,False)==word
  if a!=b:mismatch+=1
 print('PYTHON_ALGEBRA_CHECK_OK 10000 words, 0-error encode/decode; modes differ on',mismatch,'codewords')
 print('WARNING: this does not execute RTL or verify post-layout power.')
