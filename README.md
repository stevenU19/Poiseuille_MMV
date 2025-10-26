# 🌊 DualSPHysics — Modelos CUDA & ROCm
**Análisis de portabilidad y rendimiento del método SPH en arquitecturas GPU**

---

## 🧩 Descripción general

Este repositorio contiene dos implementaciones equivalentes del **flujo de Poiseuille**, del modelo **Fuerzas Externas**, mediante el método **Smoothed Particle Hydrodynamics (SPH)**, una basada en **CUDA (NVIDIA)** y otra en **ROCm/HIP (AMD)**.  

Su finalidad es la de analizar la **portabilidad, compatibilidad y rendimiento** de un mismo modelo físico en diferentes **frameworks GPU**, mostrando los desafíos técnicos y las adaptaciones necesarias al trasladar un código científico de alto rendimiento entre plataformas.

| Plataforma | Lenguaje base | Framework | Arquitectura | GPU usada |
|-------------|----------------|-------------|----------------|-------------|
| **CUDA** | C++/CUDA | CUDA Toolkit 9.1 | Fermi (SM 2.0) | NVIDIA Tesla M2050 |
| **ROCm/HIP** | C++/HIP | ROCm 6.3.0 | CDNA2 (gfx90a) | AMD Instinct MI210 |

---

## 🧾 Autores

Proyecto desarrollado por:  
**Wilmer Farfán** y **Fabián Sánchez**  

Como parte del trabajo de grado titulado:  
> *“Análisis de la portabilidad de la implementación de métodos numéricos de hidrodinámica de partículas suaves en diferentes plataformas y frameworks CPU/GPU.”*
