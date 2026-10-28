"""Audio original sintetizado para el proyecto. Sin muestras de terceros."""
from pathlib import Path
import wave
import numpy as np
from scipy.signal import butter,sosfilt
OUT=Path(__file__).resolve().parents[1]/"assets"/"audio"
OUT.mkdir(parents=True,exist_ok=True)
SR=22050
rng=np.random.default_rng(1806)
def save(name,y):
 y=np.clip(y,-.95,.95)
 with wave.open(str(OUT/(name+".wav")),"wb") as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes((y*32767).astype("<i2").tobytes())
def noise(n,cut):return sosfilt(butter(3,cut,fs=SR,output="sos"),rng.normal(0,1,n))
t=np.arange(int(SR*.24))/SR
save("order",(np.sin(2*np.pi*(540*t+180*t*t))*.22+noise(len(t),2100)*.12)*np.exp(-t*22))
save("error",np.sin(2*np.pi*180*t)*np.sin(np.pi*t/.24)*.14)
t=np.arange(int(SR*2.2))/SR
save("cannon",(noise(len(t),800)*2.2+np.sin(2*np.pi*48*t)*.22)*np.exp(-t*3.4)*(1-np.exp(-t*80)))
t=np.arange(int(SR*.25))/SR
save("hoof",noise(len(t),1000)*.9*np.exp(-t*35)+np.sin(2*np.pi*130*t)*.12*np.exp(-t*30))
t=np.arange(SR*3)/SR
y=np.zeros(len(t))
for i,f in enumerate([220,277.18,329.63,440]):
 start=i*.2;gate=(t>=start);tt=np.maximum(0,t-start);y+=gate*np.sin(2*np.pi*f*tt)*np.exp(-tt*1.9)*.12*(1-np.exp(-tt*30))
save("victory",y)
t=np.arange(SR*12)/SR
y=noise(len(t),1200)*(.18+.10*np.sin(2*np.pi*t/4))
fade=np.minimum(1,np.minimum(t,12-t)*2)
save("river",y*fade)
save("wind",noise(len(t),380)*(.15+.05*np.sin(2*np.pi*t/6))*fade)
print("Generated",len(list(OUT.glob("*.wav"))),"original sounds")
