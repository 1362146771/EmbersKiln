"""Measure the rigid ceramic mask to correct drawing-scale drift, not pose height."""
import numpy as np

def mask_length(image):
 a=np.array(image.convert('RGBA'));r,g,b=[a[:,:,i].astype(float) for i in range(3)];opaque=a[:,:,3]>200
 y,x=np.where(opaque); top=y.min();h=y.max()-top
 skin=opaque&(r>g*1.3)&(g>b*1.2)&(r>120)&(g>65)&(np.indices(r.shape)[0]<top+h*.65)
 cream=opaque&(r>140)&(g>120)&(b>85)&(r>b*1.06)&(r<g*1.24)&(np.indices(r.shape)[0]<top+h*.5)
 labels=np.zeros(cream.shape,dtype=np.int32);sizes=[0];n=0
 for y0,x0 in zip(*np.where(cream)):
  if labels[y0,x0]:continue
  n+=1; stack=[(y0,x0)];labels[y0,x0]=n;count=0
  while stack:
   yy,xx=stack.pop();count+=1
   for y1,x1 in ((yy-1,xx),(yy+1,xx),(yy,xx-1),(yy,xx+1)):
    if 0<=y1<cream.shape[0] and 0<=x1<cream.shape[1] and cream[y1,x1] and not labels[y1,x1]:labels[y1,x1]=n;stack.append((y1,x1))
  sizes.append(count)
 label=int(np.argmax(sizes))
 yy,xx=np.where(labels==label)
 assert len(xx)>100, 'Ceramic mask landmark missing'
 points=np.column_stack((xx,yy))
 _,axes=np.linalg.eigh(np.cov(points.T))
 return float(np.ptp(points@axes[:,-1]))
