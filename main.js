import * as THREE from 'three';
const canvas=document.querySelector('#scene'), stage=document.querySelector('.stage-wrap');
const renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:true,powerPreference:'high-performance'});
renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.18;
const scene=new THREE.Scene();scene.fog=new THREE.FogExp2(0x160d20,.075);
const camera=new THREE.PerspectiveCamera(34,1,.1,100);camera.position.set(0,0,9.7);
scene.add(new THREE.HemisphereLight(0xe8d8ff,0x281025,2.0));
const key=new THREE.DirectionalLight(0xffe6f6,4.2);key.position.set(-4,6,6);scene.add(key);
const rim=new THREE.DirectionalLight(0xff4db9,3.5);rim.position.set(5,1,-4);scene.add(rim);
const fill=new THREE.PointLight(0x9b66ff,22,14);fill.position.set(-3,-1,3);scene.add(fill);
const floor=new THREE.Mesh(new THREE.CircleGeometry(3.4,64),new THREE.MeshBasicMaterial({color:0x4a1645,transparent:true,opacity:.16}));floor.rotation.x=-Math.PI/2;floor.position.y=-1.8;scene.add(floor);
// Orbit ring and its glowing marker
const orbit=new THREE.Mesh(new THREE.TorusGeometry(2.45,.008,8,180),new THREE.MeshBasicMaterial({color:0xff8bd3,transparent:true,opacity:.5}));orbit.rotation.set(1.14,.1,-.2);orbit.position.y=-.03;scene.add(orbit);
const marker=new THREE.Mesh(new THREE.SphereGeometry(.075,18,14),new THREE.MeshBasicMaterial({color:0xffffff}));scene.add(marker);
const specs={pink:{name:'Pink Citrus',flavor:'PINK CITRUS',base:'#ff50b7',light:'#ffc2e8',dark:'#70134f',accent:'#fff0a6'},berry:{name:'Berry Blast',flavor:'BERRY BLAST',base:'#7936ff',light:'#d7b8ff',dark:'#321066',accent:'#bafff4'},citrus:{name:'Citrus Charge',flavor:'CITRUS CHARGE',base:'#ff8b20',light:'#ffe2a2',dark:'#8a3510',accent:'#fff5a5'}};
function labelTexture(s){const c=document.createElement('canvas');c.width=512;c.height=1024;const x=c.getContext('2d');const g=x.createLinearGradient(0,0,512,0);g.addColorStop(0,s.dark);g.addColorStop(.16,s.base);g.addColorStop(.36,s.light);g.addColorStop(.49,s.base);g.addColorStop(.72,s.dark);g.addColorStop(.88,s.base);g.addColorStop(1,s.dark);x.fillStyle=g;x.fillRect(0,0,512,1024);
// print-style graphics, baked onto the cylindrical label texture
x.globalAlpha=.18;for(let i=0;i<9;i++){x.strokeStyle='#fff';x.lineWidth=2;x.beginPath();x.arc(256,520,100+i*29,-.8,2.5);x.stroke()}x.globalAlpha=1;
x.textAlign='center';x.fillStyle='#fff';x.font='900 27px Arial';x.letterSpacing='7px';x.fillText('ENERGY / EST. 2026',256,245);
x.shadowColor='#24041c';x.shadowBlur=5;x.fillStyle='#fff';x.font='1000 118px Arial Black, Arial';x.fillText('VOLT',256,405);x.shadowBlur=0;
x.fillStyle=s.accent;x.font='bold 150px Arial';x.fillText('ϟ',256,570);
x.strokeStyle='#ffffffcc';x.lineWidth=3;x.beginPath();x.moveTo(90,640);x.lineTo(422,640);x.stroke();
x.fillStyle='#fff';x.font='900 30px Arial';x.letterSpacing='4px';x.fillText(s.flavor,256,700);
x.font='bold 21px Arial';x.letterSpacing='3px';x.fillText('250 ML  •  FULL CHARGE',256,750);
x.globalAlpha=.3;x.fillStyle='#fff';x.font='bold 18px Arial';x.fillText('ELECTRIC ENERGY',256,915);x.globalAlpha=1;
const tex=new THREE.CanvasTexture(c);tex.colorSpace=THREE.SRGBColorSpace;tex.anisotropy=renderer.capabilities.getMaxAnisotropy();return tex;}
function makeCan(key,x,y,z,scale){const s=specs[key],group=new THREE.Group();group.position.set(x,y,z);group.scale.setScalar(scale);group.userData={key,baseY:y,phase:Math.random()*Math.PI*2};
const bodyMat=new THREE.MeshStandardMaterial({map:labelTexture(s),metalness:.48,roughness:.28,metalnessMap:null});
const body=new THREE.Mesh(new THREE.CylinderGeometry(.66,.66,2.85,96,1,false),bodyMat);group.add(body);
// tapered shoulders and neck create a recognizable aluminum beverage-can silhouette
const shoulderMat=new THREE.MeshStandardMaterial({color:s.base,metalness:.7,roughness:.24});const shoulder=new THREE.Mesh(new THREE.CylinderGeometry(.57,.66,.22,96),shoulderMat);shoulder.position.y=1.48;group.add(shoulder);
const neck=new THREE.Mesh(new THREE.CylinderGeometry(.54,.57,.12,96),new THREE.MeshStandardMaterial({color:0xb9b7c2,metalness:.92,roughness:.2}));neck.position.y=1.63;group.add(neck);
const silver=new THREE.MeshStandardMaterial({color:0xc9c8d0,metalness:.95,roughness:.19});
const lid=new THREE.Mesh(new THREE.CylinderGeometry(.55,.55,.085,96),silver);lid.position.y=1.72;group.add(lid);
const lidInset=new THREE.Mesh(new THREE.CylinderGeometry(.45,.45,.012,96),new THREE.MeshStandardMaterial({color:0x777782,metalness:.85,roughness:.3}));lidInset.position.y=1.77;group.add(lidInset);
const rimTop=new THREE.Mesh(new THREE.TorusGeometry(.55,.035,12,96),new THREE.MeshStandardMaterial({color:0xf2f0f8,metalness:.96,roughness:.16}));rimTop.rotation.x=Math.PI/2;rimTop.position.y=1.73;group.add(rimTop);
const bottom=new THREE.Mesh(new THREE.CylinderGeometry(.57,.57,.07,96),silver);bottom.position.y=-1.44;group.add(bottom);
const rimBottom=new THREE.Mesh(new THREE.TorusGeometry(.57,.03,10,96),silver);rimBottom.rotation.x=Math.PI/2;rimBottom.position.y=-1.44;group.add(rimBottom);
// Pull tab: metal ring plus rivet on the top lid
const tab=new THREE.Mesh(new THREE.TorusGeometry(.13,.027,10,32),new THREE.MeshStandardMaterial({color:0x686874,metalness:.95,roughness:.2}));tab.rotation.x=Math.PI/2;tab.position.set(0,1.79,-.045);tab.scale.set(.72,1.25,1);group.add(tab);
const rivet=new THREE.Mesh(new THREE.CylinderGeometry(.045,.045,.018,24),silver);rivet.position.set(0,1.79,.13);group.add(rivet);
// slim specular vertical strip, like a studio softbox reflection
const strip=new THREE.Mesh(new THREE.PlaneGeometry(.09,2.45),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.2,side:THREE.DoubleSide,blending:THREE.AdditiveBlending}));strip.position.set(-.36,.05,.575);strip.rotation.y=-.3;group.add(strip);
scene.add(group);return group;}
const cans=[makeCan('berry',-1.75,-.12,-.4,.78),makeCan('citrus',1.7,-.13,-.15,.8),makeCan('pink',0,.02,.55,1)];let active='pink';
function selectFlavor(k){active=k;const order={pink:[0,1,2],berry:[1,2,0],citrus:[2,0,1]},ids=order[k];ids.forEach((idx,rank)=>{const c=cans[idx];c.userData.targetX=rank===0?0:(rank===1?-1.72:1.72);c.userData.targetY=rank===0?.03:-.13;c.userData.targetZ=rank===0?.62:-.38;c.userData.targetScale=rank===0?1:.78;c.userData.targetRot=rank===0?-.08:(rank===1?-.28:.28);});document.querySelector('#current').textContent=specs[k].name;document.querySelectorAll('.swatch').forEach(b=>b.classList.toggle('active',b.dataset.pick===k));}
selectFlavor('pink');document.querySelectorAll('.swatch').forEach(b=>b.addEventListener('click',()=>selectFlavor(b.dataset.pick)));
let pointerX=0,pointerY=0,dragging=false,lastX=0,lastY=0,rotationY=0,rotationX=0;canvas.addEventListener('pointerdown',e=>{dragging=true;lastX=e.clientX;lastY=e.clientY;canvas.setPointerCapture(e.pointerId)});canvas.addEventListener('pointermove',e=>{const r=stage.getBoundingClientRect();pointerX=(e.clientX-r.left)/r.width-.5;pointerY=(e.clientY-r.top)/r.height-.5;if(dragging){rotationY+=(e.clientX-lastX)*.009;rotationX+=(e.clientY-lastY)*.005;rotationX=THREE.MathUtils.clamp(rotationX,-.42,.42);lastX=e.clientX;lastY=e.clientY}});canvas.addEventListener('pointerup',()=>dragging=false);canvas.addEventListener('pointercancel',()=>dragging=false);
const clock=new THREE.Clock();function resize(){const w=stage.clientWidth,h=stage.clientHeight;renderer.setSize(w,h,false);camera.aspect=w/h;camera.position.z=w<500?11.6:9.7;camera.updateProjectionMatrix()}new ResizeObserver(resize).observe(stage);resize();
function animate(){requestAnimationFrame(animate);const t=clock.getElapsedTime();cans.forEach((c,i)=>{const u=c.userData;c.position.x=THREE.MathUtils.damp(c.position.x,u.targetX??c.position.x,.9,.016);c.position.y=THREE.MathUtils.damp(c.position.y,(u.targetY??u.baseY)+Math.sin(t*1.15+u.phase)*.09,.9,.016);c.position.z=THREE.MathUtils.damp(c.position.z,u.targetZ??0,.9,.016);const sc=THREE.MathUtils.damp(c.scale.x,u.targetScale??1,.9,.016);c.scale.setScalar(sc);c.rotation.y=THREE.MathUtils.damp(c.rotation.y,(u.targetRot??0)+Math.sin(t*.45+u.phase)*.12+pointerX*.22,.9,.016);c.rotation.x=THREE.MathUtils.damp(c.rotation.x,rotationX+pointerY*.08,.9,.016);c.rotation.z=THREE.MathUtils.damp(c.rotation.z,Math.sin(t*.7+u.phase)*.035,.9,.016);});orbit.rotation.z=t*.09;marker.position.set(Math.cos(t*.65)*2.45,Math.sin(t*.65)*.2,Math.sin(t*.65)*1.2);renderer.render(scene,camera)}animate();
