"use client";

import { useMemo, useRef } from "react";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import {
  Environment,
  Float,
  Lightformer,
  Sparkles,
} from "@react-three/drei";
import * as THREE from "three";

/*
 * Hero scene: the Zad carrot (the app's logo, rebuilt in 3D) with the three
 * things it looks after orbiting it: money (coins), the kitchen (glass jars of
 * the pantry, as glass spheres) and medicine (capsules). Lighting is built from
 * Lightformers so nothing is fetched from a CDN at runtime.
 */

const CARROT = "#f0703d";
const LEAF = "#3ca06e";
const BONE = "#eef2ec";

// Body radius at height y (tip at -1.55, crown at 1.55).
function radiusAt(y: number) {
  const t = (y + 1.55) / 3.1;
  return 0.62 * Math.pow(Math.sin((t * Math.PI) / 2), 0.9) * (1 - 0.18 * t * t) + 0.012;
}

function Carrot() {
  const body = useMemo(() => {
    const pts: THREE.Vector2[] = [];
    for (let i = 0; i <= 40; i++) {
      const y = (i / 40) * 3.1 - 1.55;
      pts.push(new THREE.Vector2(radiusAt(y), y));
    }
    pts.push(new THREE.Vector2(0, 1.55));
    return new THREE.LatheGeometry(pts, 96);
  }, []);

  const leaves = useMemo(
    () =>
      [
        [-0.28, 0.9, 0.1, -0.25],
        [0, 1.15, 0, 0],
        [0.3, 0.85, -0.1, 0.3],
      ].map(([x, h, z, lean]) => {
        const curve = new THREE.CatmullRomCurve3([
          new THREE.Vector3(x * 0.4, 1.5, z * 0.4),
          new THREE.Vector3(x * 0.8 + lean * 0.3, 1.5 + h * 0.5, z),
          new THREE.Vector3(x + lean * 0.8, 1.5 + h, z * 1.3),
        ]);
        return new THREE.TubeGeometry(curve, 40, 0.07, 16, false);
      }),
    [],
  );

  // The three pale grooves from the logo.
  const grooves = [0.6, 0.05, -0.5].map((y) => ({ y, r: radiusAt(y) - 0.004 }));

  return (
    <group rotation={[0, 0, -0.32]}>
      <mesh geometry={body} castShadow>
        <meshPhysicalMaterial
          color={CARROT}
          roughness={0.32}
          clearcoat={1}
          clearcoatRoughness={0.18}
          sheen={0.6}
          sheenColor="#ffd2bd"
        />
      </mesh>
      {grooves.map((g) => (
        <mesh key={g.y} position={[0, g.y, 0]} rotation={[Math.PI / 2 + 0.1, 0, Math.PI * 0.2]}>
          <torusGeometry args={[g.r, 0.018, 12, 64, Math.PI * 0.55]} />
          <meshStandardMaterial color={BONE} roughness={0.4} />
        </mesh>
      ))}
      {leaves.map((geo, i) => (
        <mesh key={i} geometry={geo}>
          <meshPhysicalMaterial color={LEAF} roughness={0.35} clearcoat={0.6} />
        </mesh>
      ))}
    </group>
  );
}

function Coin({ position, rotation }: { position: [number, number, number]; rotation: number }) {
  return (
    <group position={position} rotation={[Math.PI / 2.4, rotation, 0.3]}>
      <mesh>
        <cylinderGeometry args={[0.34, 0.34, 0.07, 64]} />
        <meshStandardMaterial color="#f3cf94" metalness={0.85} roughness={0.28} envMapIntensity={1.6} />
      </mesh>
      <mesh position={[0, 0.037, 0]}>
        <torusGeometry args={[0.27, 0.012, 8, 64]} />
        <meshStandardMaterial color="#fff1d6" metalness={1} roughness={0.15} />
      </mesh>
    </group>
  );
}

function Capsule({ position, rotation }: { position: [number, number, number]; rotation: [number, number, number] }) {
  return (
    <group position={position} rotation={rotation}>
      <mesh position={[0, 0.16, 0]}>
        <capsuleGeometry args={[0.13, 0.32, 8, 24]} />
        <meshPhysicalMaterial color={CARROT} roughness={0.2} clearcoat={1} />
      </mesh>
      <mesh position={[0, -0.16, 0]}>
        <capsuleGeometry args={[0.13, 0.32, 8, 24]} />
        <meshPhysicalMaterial color={BONE} roughness={0.25} clearcoat={1} />
      </mesh>
    </group>
  );
}

function GlassJar({ position, scale = 1 }: { position: [number, number, number]; scale?: number }) {
  return (
    <mesh position={position} scale={scale}>
      <sphereGeometry args={[0.42, 64, 64]} />
      {/* Soap-bubble glass: reads on a transparent canvas, unlike transmission. */}
      <meshPhysicalMaterial
        color="#ffffff"
        transparent
        opacity={0.28}
        roughness={0.05}
        metalness={0.1}
        iridescence={1}
        iridescenceIOR={1.3}
        clearcoat={1}
        envMapIntensity={2}
        depthWrite={false}
      />
    </mesh>
  );
}

function Rig({ reduced, children }: { reduced: boolean; children: React.ReactNode }) {
  const group = useRef<THREE.Group>(null);
  const { viewport } = useThree();
  // Wide screens: the scene sits in the left half (RTL copy is on the right).
  // Narrow screens: it sits above the copy.
  const wide = viewport.width > 7;
  const place: [number, number, number] = wide
    ? [-viewport.width * 0.24, 0, 0]
    : [0, viewport.height * 0.2, 0];
  const scale = wide ? Math.min(1, viewport.height / 7.2) : Math.min(0.62, viewport.width / 6.5);
  const orbit = useRef<THREE.Group>(null);

  useFrame((state, delta) => {
    if (!group.current || !orbit.current) return;
    const { x, y } = state.pointer;
    group.current.rotation.y = THREE.MathUtils.damp(group.current.rotation.y, x * 0.45, 3, delta);
    group.current.rotation.x = THREE.MathUtils.damp(group.current.rotation.x, -y * 0.25, 3, delta);
    if (!reduced) orbit.current.rotation.y += delta * 0.18;
  });

  return (
    <group position={place} scale={scale}>
    <group ref={group}>
      {children}
      <group ref={orbit}>
        <Float speed={reduced ? 0 : 2} rotationIntensity={1.2} floatIntensity={1.2}>
          <Coin position={[1.9, 0.9, 0.4]} rotation={0.4} />
        </Float>
        <Float speed={reduced ? 0 : 1.6} rotationIntensity={1.4} floatIntensity={1}>
          <Coin position={[-1.6, -1.2, 0.9]} rotation={-0.8} />
        </Float>
        <Float speed={reduced ? 0 : 1.8} rotationIntensity={2} floatIntensity={1.4}>
          <Capsule position={[-1.9, 1.1, -0.4]} rotation={[0.4, 0, 0.9]} />
        </Float>
        <Float speed={reduced ? 0 : 1.4} rotationIntensity={1.6} floatIntensity={1.1}>
          <Capsule position={[1.5, -1.5, -0.6]} rotation={[0.2, 0.4, -0.6]} />
        </Float>
        <Float speed={reduced ? 0 : 1.2} rotationIntensity={0.4} floatIntensity={1.6}>
          <GlassJar position={[0.2, 1.9, 1.1]} scale={0.8} />
        </Float>
        <Float speed={reduced ? 0 : 1.1} rotationIntensity={0.4} floatIntensity={1.3}>
          <GlassJar position={[-0.9, -0.3, 1.6]} scale={0.6} />
        </Float>
      </group>
    </group>
    </group>
  );
}

export default function HeroScene({ reduced = false }: { reduced?: boolean }) {
  return (
    <Canvas
      dpr={[1, 1.75]}
      camera={{ position: [0, 0, 8], fov: 38 }}
      gl={{ antialias: true, alpha: true, powerPreference: "high-performance" }}
      aria-hidden
    >
      <ambientLight intensity={0.25} />
      <directionalLight position={[3, 4, 5]} intensity={1.6} color="#fff4ea" />
      <pointLight position={[-4, -2, 2]} intensity={18} color={CARROT} distance={12} />
      <Rig reduced={reduced}>
        <Float speed={reduced ? 0 : 1.4} rotationIntensity={0.5} floatIntensity={0.8}>
          <Carrot />
        </Float>
      </Rig>
      <Sparkles count={70} scale={[8, 6, 4]} size={2.2} speed={reduced ? 0 : 0.35} color="#ffb38f" opacity={0.6} />
      <Environment resolution={256}>
        <Lightformer form="rect" intensity={3} position={[0, 4, 3]} scale={[8, 2, 1]} color="#ffffff" />
        <Lightformer form="rect" intensity={2.2} position={[-5, 0, 1]} rotation-y={Math.PI / 2} scale={[6, 3, 1]} color="#ffd9c7" />
        <Lightformer form="ring" intensity={2.5} position={[4, 1, -2]} scale={2} color={CARROT} />
        <Lightformer form="rect" intensity={1.2} position={[0, -4, 2]} scale={[8, 1, 1]} color={LEAF} />
      </Environment>
    </Canvas>
  );
}
