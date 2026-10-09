import * as THREE from 'three';

const canvas = document.querySelector('#scene');
const label = document.querySelector('#current');
const buttons = [...document.querySelectorAll('[data-pick]')];
const flavors = {
  pink: { name: 'Pink Citrus', body: '#ed399d', light: '#ff78c5', accent: '#ffd7f0' },
  berry: { name: 'Berry Blast', body: '#7545db', light: '#aa8bff', accent: '#efe6ff' },
  citrus: { name: 'Citrus Charge', body: '#ed8426', light: '#ffbd59', accent: '#fff0c7' }
};

let active = 'pink', renderer, scene, camera, cans = [], rings;
let pointer = { x: 0, y: 0 }, target = { x: 0, y: 0 }, rotation = 0;
let drag = false, lastX = 0, lastY = 0, frameId = 0, scrollTarget = 0, scrollOffset = 0;
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

function texture(flavor) {
  const canvasTexture = document.createElement('canvas');
  canvasTexture.width = 512;
  canvasTexture.height = 1024;
  const ctx = canvasTexture.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 512, 0);
  gradient.addColorStop(0, '#1c1025');
  gradient.addColorStop(.3, flavor.body);
  gradient.addColorStop(.55, flavor.light);
  gradient.addColorStop(.8, flavor.body);
  gradient.addColorStop(1, '#180e22');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 512, 1024);
  const shine = ctx.createLinearGradient(0, 0, 512, 0);
  shine.addColorStop(0, '#ffffff00');
  shine.addColorStop(.5, '#ffffff38');
  shine.addColorStop(1, '#ffffff00');
  ctx.fillStyle = shine;
  ctx.fillRect(0, 0, 512, 1024);
  ctx.textAlign = 'center';
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 90px Arial';
  ctx.fillText('VOLT', 256, 410);
  ctx.font = 'bold 24px Arial';
  ctx.fillText('ENERGY', 256, 455);
  ctx.fillStyle = flavor.accent;
  ctx.font = 'bold 18px Arial';
  ctx.fillText(flavor.name.toUpperCase(), 256, 545);
  ctx.fillStyle = '#ffffffcc';
  ctx.font = '15px Arial';
  ctx.fillText('SPARK YOUR EVERYDAY', 256, 590);
  ctx.strokeStyle = '#ffffff66';
  ctx.beginPath();
  ctx.moveTo(90, 485); ctx.lineTo(422, 485);
  ctx.moveTo(110, 620); ctx.lineTo(402, 620);
  ctx.stroke();
  const map = new THREE.CanvasTexture(canvasTexture);
  map.colorSpace = THREE.SRGBColorSpace;
  return map;
}

function makeCan(key, x, scale, z) {
  const flavor = flavors[key];
  const group = new THREE.Group();
  group.position.set(x, -.02, z);
  group.scale.setScalar(scale);
  const body = new THREE.Mesh(
    new THREE.CylinderGeometry(.66, .66, 2.45, 64),
    new THREE.MeshStandardMaterial({ color: flavor.body, metalness: .72, roughness: .23 })
  );
  group.add(body);
  // Condensation beads catch studio lights for a colder, more tactile finish.
  const dropletMaterial = new THREE.MeshPhysicalMaterial({ color: '#eaf7ff', roughness: .08, metalness: .05, transparent: true, opacity: .62, clearcoat: 1, clearcoatRoughness: .05 });
  for (let i = 0; i < 38; i++) {
    const angle = Math.random() * Math.PI * 2;
    const y = (Math.random() - .5) * 2.12;
    const drop = new THREE.Mesh(new THREE.SphereGeometry(.012 + Math.random() * .018, 8, 8), dropletMaterial);
    drop.position.set(Math.sin(angle) * .667, y, Math.cos(angle) * .667);
    drop.scale.set(.75, 1.25, .6);
    group.add(drop);
  }
  const labelMesh = new THREE.Mesh(
    new THREE.CylinderGeometry(.665, .665, 1.83, 64, 1, true),
    new THREE.MeshStandardMaterial({ map: texture(flavor), metalness: .2, roughness: .32 })
  );
  labelMesh.position.y = -.03;
  group.add(labelMesh);
  const silver = new THREE.MeshStandardMaterial({ color: '#c7cbd5', metalness: .95, roughness: .16 });
  const dark = new THREE.MeshStandardMaterial({ color: '#626574', metalness: .9, roughness: .22 });
  const top = new THREE.Mesh(new THREE.CylinderGeometry(.61, .61, .085, 64), silver);
  top.position.y = 1.25;
  group.add(top);
  const rim = new THREE.Mesh(new THREE.TorusGeometry(.605, .04, 12, 64), dark);
  rim.rotation.x = Math.PI / 2;
  rim.position.y = 1.28;
  group.add(rim);
  const lid = new THREE.Mesh(new THREE.CylinderGeometry(.48, .48, .018, 64), dark);
  lid.position.y = 1.30;
  group.add(lid);
  const tab = new THREE.Mesh(new THREE.TorusGeometry(.105, .022, 8, 24), new THREE.MeshStandardMaterial({ color: '#aeb4c1', metalness: .96, roughness: .19 }));
  tab.rotation.x = Math.PI / 2;
  tab.position.set(0, 1.316, .09);
  tab.scale.set(1, 1.45, 1);
  group.add(tab);
  const bottom = new THREE.Mesh(new THREE.CylinderGeometry(.59, .59, .075, 64), silver);
  bottom.position.y = -1.24;
  group.add(bottom);
  group.userData = { key, baseY: -.02, targetScale: scale, targetZ: z };
  return group;
}

function select(key) {
  if (!flavors[key]) return;
  active = key;
  label.textContent = flavors[key].name;
  const number = document.querySelector('.active-number');
  const dot = document.querySelector('.active-flavor-dot');
  const color = key === 'pink' ? '#ff1687' : key === 'berry' ? '#ad62ff' : '#ff8a35';
  if (number) number.textContent = String(['pink', 'berry', 'citrus'].indexOf(key) + 1).padStart(2, '0') + ' / 03';
  if (dot) {
    dot.style.background = color;
    dot.style.boxShadow = '0 0 12px ' + color;
  }
  buttons.forEach(button => {
    const selected = button.dataset.pick === key;
    button.classList.toggle('active', selected);
    button.setAttribute('aria-pressed', String(selected));
  });
  cans.forEach(can => {
    const selected = can.userData.key === key;
    can.userData.targetScale = selected ? (key === 'pink' ? 1.03 : .9) : (can.userData.key === 'pink' ? .78 : .68);
    can.userData.targetZ = selected ? .65 : -.35;
  });
}

function resize() {
  if (!renderer || !camera) return;
  const width = Math.max(1, canvas.clientWidth);
  const height = Math.max(1, canvas.clientHeight);
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.position.z = width < 460 ? 10.8 : width < 700 ? 10 : width < 950 ? 9.5 : 8.9;
  camera.fov = width < 460 ? 39 : width < 700 ? 37 : 34;
  camera.updateProjectionMatrix();
}

function animate() {
  frameId = requestAnimationFrame(animate);
  const time = reduceMotion ? 0 : performance.now() * .001;
  scrollOffset += (scrollTarget - scrollOffset) * .025;
  pointer.x += (target.x - pointer.x) * .035;
  pointer.y += (target.y - pointer.y) * .035;
  cans.forEach((can, index) => {
    const data = can.userData;
    can.scale.setScalar(can.scale.x + (data.targetScale - can.scale.x) * .045);
    can.position.z += (data.targetZ - can.position.z) * .035;
    can.position.y = data.baseY + (reduceMotion ? 0 : Math.sin(time * 1.2 + index * 1.7) * .075) + scrollOffset * (index === 1 ? -.12 : .07);
    can.rotation.y = (reduceMotion ? 0 : time * .18 * (index % 2 ? 1 : -1)) + rotation + pointer.x * .17;
    can.rotation.x = pointer.y * -.08 + scrollOffset * .018;
  });
  if (rings) {
    rings.rotation.y = -.16 + pointer.x * .09 + (reduceMotion ? 0 : time * .035);
    rings.rotation.x = pointer.y * .04;
  }
  renderer.render(scene, camera);
}

function init() {
  if (!canvas || !window.WebGLRenderingContext) return;
  try {
    renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: 'high-performance' });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.6));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(34, 1, .1, 100);
    camera.position.set(0, .25, 8.9);
    scene.add(new THREE.HemisphereLight('#ffeaff', '#24132d', 2.1));
    const keyLight = new THREE.DirectionalLight('#fff1f8', 4.3);
    keyLight.position.set(-3, 5, 6);
    scene.add(keyLight);
    const rimLight = new THREE.DirectionalLight('#bc80ff', 3.2);
    rimLight.position.set(4, 1, -4);
    scene.add(rimLight);
    const frontLight = new THREE.PointLight('#ff78c5', 38, 12);
    frontLight.position.set(0, 1, 4);
    scene.add(frontLight);
    rings = new THREE.Group();
    scene.add(rings);
    [[2.5, .24, '#ff79d1'], [2.9, .18, '#c79aff']].forEach(([radius, opacity, color], index) => {
      const ring = new THREE.Mesh(
        new THREE.TorusGeometry(radius, .008, 8, 128),
        new THREE.MeshBasicMaterial({ color, transparent: true, opacity })
      );
      ring.rotation.x = index === 0 ? 1.12 : .92;
      ring.rotation.y = index === 0 ? -.25 : .55;
      rings.add(ring);
    });
    const particleMaterial = new THREE.MeshBasicMaterial({ color: '#ffd2f1', transparent: true, opacity: .7 });
    for (let i = 0; i < 34; i++) {
      const particle = new THREE.Mesh(new THREE.SphereGeometry(.014, 8, 8), particleMaterial);
      const angle = Math.random() * Math.PI * 2;
      const radius = 1.6 + Math.random() * 2;
      particle.position.set(Math.cos(angle) * radius, (Math.random() - .5) * 4, Math.sin(angle) * radius * .48);
      rings.add(particle);
    }
    cans = [
      makeCan('berry', -1.38, .78, -.35),
      makeCan('pink', 0, 1.03, .45),
      makeCan('citrus', 1.38, .78, -.35)
    ];
    cans.forEach((can, index) => {
      can.rotation.z = index === 1 ? -.055 : index === 0 ? .12 : -.12;
      scene.add(can);
    });
    resize();
    window.addEventListener('resize', resize, { passive: true });
    window.addEventListener('scroll', () => {
      const maxScroll = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
      scrollTarget = (window.scrollY / maxScroll) * 2 - 1;
    }, { passive: true });
    canvas.addEventListener('pointermove', event => {
      const rect = canvas.getBoundingClientRect();
      target.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      target.y = -(((event.clientY - rect.top) / rect.height) * 2 - 1);
      if (drag) {
        rotation += (event.clientX - lastX) * .008;
        lastX = event.clientX;
        lastY = event.clientY;
      }
    });
    canvas.addEventListener('pointerdown', event => {
      drag = true;
      lastX = event.clientX;
      lastY = event.clientY;
      if (canvas.setPointerCapture) canvas.setPointerCapture(event.pointerId);
    });
    const stopDrag = () => { drag = false; };
    canvas.addEventListener('pointerup', stopDrag);
    canvas.addEventListener('pointercancel', stopDrag);
    canvas.addEventListener('pointerleave', () => { if (!drag) { target.x = 0; target.y = 0; } });
    buttons.forEach(button => button.addEventListener('click', () => select(button.dataset.pick)));
    select(active);
    animate();
  } catch (error) {
    console.error('VOLT 3D failed to initialize:', error);
    canvas.setAttribute('aria-label', '3D preview unavailable. Check WebGL support and your internet connection.');
    canvas.style.display = 'none';
  }
}

// Reveal key content as it enters the viewport.
if ('IntersectionObserver' in window && !reduceMotion) {
  const revealTargets = document.querySelectorAll('.story-copy, .story-visual, .lifestyle-heading, .life-card, .closing-banner, .flavor-card');
  revealTargets.forEach((element, index) => {
    element.classList.add('reveal-ready');
    element.style.setProperty('--reveal-delay', (index % 4) * 85 + 'ms');
  });
  const revealObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        revealObserver.unobserve(entry.target);
      }
    });
  }, { threshold: .12 });
  revealTargets.forEach(element => revealObserver.observe(element));
}

// Highlight the navigation item for the section currently in view.
if ('IntersectionObserver' in window) {
  const sections = [...document.querySelectorAll('main section[id]')];
  const navLinks = [...document.querySelectorAll('.main-nav a')];
  const navObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      navLinks.forEach(link => link.classList.toggle('nav-active', link.getAttribute('href') === '#' + entry.target.id));
    });
  }, { rootMargin: '-30% 0px -60% 0px' });
  sections.forEach(section => navObserver.observe(section));
}

document.querySelectorAll('a[href^="#"]').forEach(link => {
  link.addEventListener('click', event => {
    const targetElement = document.querySelector(link.getAttribute('href'));
    if (targetElement) {
      event.preventDefault();
      targetElement.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'start' });
    }
  });
});

window.addEventListener('pagehide', () => {
  if (frameId) cancelAnimationFrame(frameId);
  if (renderer) renderer.dispose();
});

init();
