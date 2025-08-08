# GEST: Graph of Events in Space and Time as a Common Representation between Vision and Language

This repository implements the research system described in **"Graph of Events in Space and Time as a Common Representation between Vision and Language"**. The system generates and executes complex multi-actor interactive narratives in a 3D game environment using the MTA San Andreas engine.

## Research Overview

This project introduces **GEST (Graph of Events in Space and Time)**, a novel common representation that bridges vision and language through spatiotemporal event graphs. The system demonstrates how abstract story graphs can be grounded in concrete 3D embodied simulation, enabling researchers to study the intersection of visual understanding, natural language processing, and interactive narrative systems.

### Key Contributions

- **Common Vision-Language Representation**: GEST graphs serve as a unified representation bridging visual scenes and natural language descriptions
- **Spatiotemporal Event Modeling**: Novel formalism for representing events with explicit spatial and temporal relationships
- **3D Grounding System**: Algorithms for grounding abstract language-derived events in concrete 3D visual simulations  
- **Multi-Modal Validation**: Framework for validating story coherence across visual and linguistic modalities
- **Embodied Narrative Generation**: System for generating and executing narratives that are both linguistically coherent and visually plausible

### Research Applications

- **Vision-Language Understanding**: Bridge between textual story descriptions and visual scene understanding
- **Multi-Modal AI**: Common representation for systems processing both visual and textual information
- **Embodied AI**: Study of how language-described events can be realized in 3D environments
- **Narrative Visualization**: Automatic generation of visual stories from textual descriptions
- **Cross-Modal Learning**: Research on shared representations between vision and language domains

## Publications

### Our Work

**Primary Publication**: See `docs/our publications/GEST.pdf` for the comprehensive description of:
- GEST graph formalism and syntax
- 3D simulation engine architecture  
- Graph-to-simulation mapping algorithms
- Experimental validation and results

### Related Work

The `docs/related work/` folder contains key papers that inform our research:

- **Scene Graph Generation**: Papers on video scene graph generation and anticipation
- **Latent Diffusion Models**: Research on scene graph conditioning for content generation
- **Video Summarization**: Graph-based approaches to video understanding and generation
- **Virtual Environments**: Studies on procedural content generation for 3D worlds

## System Architecture

This implementation consists of:

### Core Engine (`story/`)
- **GraphStory.lua**: Main story execution engine processing GEST graphs
- **ActionsOrchestrator.lua**: Multi-agent temporal coordination system
- **Episodes**: 3D environment definitions with objects and interaction points

### Story Processing Pipeline
1. **Graph Loading**: Parse GEST JSON input format
2. **Episode Validation**: Match story requirements to available 3D environments  
3. **Object Mapping**: Map abstract objects to concrete 3D entities with chain consistency
4. **Action Orchestration**: Execute actions with temporal constraint satisfaction
5. **3D Simulation**: Render embodied simulation with camera recording

### Research Tools
- **Story Generator** (`story_generator/`): Python tools for synthetic GEST graph generation
- **Test Framework** (`test_framework/`): Standalone testing infrastructure with mock 3D engine
- **Validation Suite**: Comprehensive testing of chain ID consistency and temporal constraints

## Getting Started

### Prerequisites
- Lua 5.1+ interpreter
- MTA San Andreas (for full 3D simulation)
- Python 3.x (for story generation tools)

### Running Tests
```bash
# Standalone testing (no game engine required)
lua run_tests_standalone.lua

# Or use platform-specific wrapper
./run_tests.sh        # Linux/macOS
run_tests.bat          # Windows
```

### Story Generation
```bash
cd story_generator/
python main.py
```

### Research Usage

1. **Story Design**: Create GEST graphs in JSON format (see examples in `input_graphs/`)
2. **Episode Creation**: Define 3D environments in `files/episodes/`
3. **Validation**: Use test framework to verify story-environment compatibility
4. **Simulation**: Execute full 3D simulation with data logging
5. **Analysis**: Process generated logs and screenshots for research analysis

## Research Data

The system generates comprehensive data for research analysis:
- **Action Sequences**: Complete logs of executed actions with timing
- **Spatial Data**: Actor positions and movements throughout simulation
- **Object Interactions**: Detailed interaction patterns and object usage
- **Temporal Metrics**: Constraint satisfaction and synchronization data
- **Visual Output**: Screenshot sequences for qualitative analysis

## Contact & Collaboration

For research collaborations, dataset requests, or technical questions about the GEST framework, please refer to the contact information in our publications.

## Citation

If you use this work in your research, please cite our GEST paper (details in `docs/our publications/GEST.pdf`).