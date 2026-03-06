# Isaac Sim and Isaac Lab Playbook

NVIDIA Isaac Sim (physics simulation) and Isaac Lab (reinforcement learning
training) on the DGX Spark for robotics development.

## Quick Start

### Container (recommended for quick start)

Run Isaac Sim in headless mode:

```bash
isaac-sim-container
```

For GUI mode with X11 display:

```bash
export DISPLAY=:0
xhost +local:
isaac-sim-container
```

### Build from Source (recommended for DGX Spark)

The NVIDIA DGX Spark instructions recommend building from source for best
performance on the Grace Blackwell GB10 architecture:

1. Enter the devshell:

   ```bash
   nix develop .#isaac-sim
   ```

2. Clone and build Isaac Sim:

   ```bash
   git clone --depth=1 --recursive https://github.com/isaac-sim/IsaacSim
   cd IsaacSim
   git lfs install && git lfs pull
   ./build.sh
   ```

3. Configure the environment:

   ```bash
   export ISAACSIM_PATH="${PWD}/_build/linux-aarch64/release"
   export ISAACSIM_PYTHON_EXE="${ISAACSIM_PATH}/python.sh"
   ```

4. Launch Isaac Sim:

   ```bash
   ${ISAACSIM_PATH}/isaac-sim.sh
   ```

### Isaac Lab

1. Clone and install Isaac Lab:

   ```bash
   git clone https://github.com/isaac-sim/IsaacLab
   cd IsaacLab
   ln -s /path/to/IsaacSim/_build/linux-aarch64/release _isaac_sim
   ./isaaclab.sh --install
   ```

2. Run a training example (headless mode recommended):

   ```bash
   ./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py \
     --task=Isaac-Velocity-Rough-H1-v0 --headless
   ```

## Features

- Physics-based robot simulation with GPU acceleration
- Isaac Lab for reinforcement learning training
- Support for headless and GUI modes
- USD (Universal Scene Description) scene format

> **Note:** DGX Spark hardware with NVIDIA GPU is required. Isaac Sim has
> significant GPU memory requirements (50 GB+ storage recommended).

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/isaac/instructions)
- [Isaac Sim Documentation](https://docs.isaacsim.omniverse.nvidia.com/latest/)
- [Isaac Lab Documentation](https://isaac-sim.github.io/IsaacLab/main/)
