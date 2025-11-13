const { ipcRenderer } = require('electron');
const fs = require('fs');

document.addEventListener('DOMContentLoaded', () => {
    const dropzone = document.getElementById('dropzone');
    const cyContainer = document.getElementById('cy');
    const toggleButtons = document.getElementById('toggle-buttons');

    let headlessConfig = null; // Will store {inputPath, outputPath} in headless mode

    const cy = cytoscape({
        container: cyContainer,
        elements: [],
        style: [
            {
                selector: 'node',
                style: {
                    'label': 'data(id)',
                    'text-valign': 'top',
                    'text-halign': 'center',
                    'shape': 'roundrectangle',
                    'width': 'label',
                    'height': 'label',
                    'padding': 10,
                    'border-width': 2,
                    'border-color': '#333',
                    'text-wrap': 'wrap',
                    'text-max-width': 150,
                    'font-size': '5px',
                    'content': 'data(details)',
                    'text-valign': 'center',
                    'z-index': 0,
                    'z-compound-depth': 'bottom'
                }
            },
            { selector: 'node.entity', style: { 'background-color': '#007bff', 'color': 'white' } }, // Blue for entities
            { selector: 'node.actor', style: { 'background-color': '#4caf50', 'color': 'white' } }, // Green for actors
            { selector: 'node.event', style: { 'background-color': '#ff9800', 'color': 'white' } }, // Orange for events
            { selector: 'node.scene', style: { 'border-width': 3, 'font-weight': 'bold' } }, // Scene nodes have bold border
            { selector: 'node.parent', style: { 'background-color': '#9c27b0', 'color': 'white', 'width': 80, 'height': 80 } }, // Purple for parent scenes
            { selector: 'node.leaf', style: { 'background-color': '#00bcd4', 'color': 'white', 'width': 60, 'height': 60 } }, // Cyan for leaf scenes
            {
                selector: 'edge',
                style: {
                    'width': 2,
                    'line-color': '#ccc',
                    'target-arrow-color': '#ccc',
                    'target-arrow-shape': 'triangle',
                    'label': 'data(label)',
                    'font-size': '5px',
                    'text-background-color': '#fff',
                    'text-background-opacity': 1,
                    'text-background-padding': 0,
                    'z-index': 1000,
                    'z-compound-depth': 'top',
                    'curve-style': 'bezier',
                }
            },
            { selector: '.same-entity', style: { 'line-color': 'green', 'target-arrow-color': 'green' } },
            { selector: '.temporal', style: { 'line-color': 'red', 'target-arrow-color': 'red' } },
            { selector: '.temporal-relation', style: { 'line-color': 'blue', 'target-arrow-color': 'blue' } },
            { selector: '.semantic-relation', style: { 'line-color': '#9c27b0', 'target-arrow-color': '#9c27b0', 'line-style': 'dashed', 'width': 2 } }, // Purple dashed for semantic
            { selector: '.logical-relation', style: { 'line-color': '#ff5722', 'target-arrow-color': '#ff5722', 'line-style': 'dotted', 'width': 2, 'curve-style': 'unbundled-bezier', 'control-point-distances': 40, 'control-point-weights': 0.5 } }, // Orange dotted for logical
            { selector: '.hidden', style: { 'display': 'none' } }
        ],
        layout: {
            name: 'cose', nodeRepulsion: 4000, // Increase this value to add more space between nodes
            idealEdgeLength: 100, // Increase this value to add more space between connected nodes
            edgeElasticity: 100,
            gravity: 80,
            numIter: 1000,
            initialTemp: 200,
            coolingFactor: 0.95,
            minTemp: 1.0
        }
    });

    dropzone.addEventListener('click', async () => {
        const { filePaths } = await ipcRenderer.invoke('open-file-dialog');
        if (filePaths.length > 0) {
            loadGraph(filePaths[0]);
        }
    });

    dropzone.addEventListener('dragover', (event) => {
        event.preventDefault();
    });

    dropzone.addEventListener('drop', (event) => {
        event.preventDefault();
        const file = event.dataTransfer.files[0];
        if (file) {
            loadGraph(file.path);
        }
    });

    // Listen for headless mode file loading
    ipcRenderer.on('load-file-headless', (event, config) => {
        headlessConfig = config;
        console.log('Headless mode: Loading file', config.inputPath);
        loadGraph(config.inputPath);
    });

    function loadGraph(filePath) {
        fs.readFile(filePath, 'utf-8', (err, data) => {
            if (err) {
                console.error('Error reading file:', err);
                if (headlessConfig) {
                    ipcRenderer.send('export-error', `Failed to read file: ${err.message}`);
                }
                return;
            }
            try {
                const graphData = JSON.parse(data);
                renderGraph(graphData);
            } catch (error) {
                console.error('Invalid JSON format:', error);
                if (headlessConfig) {
                    ipcRenderer.send('export-error', `Invalid JSON: ${error.message}`);
                }
            }
        });
    }

    function renderGraph(data) {
        cy.elements().remove();
        const elements = [];

        // PASS 1: Create all nodes with complete data
        Object.keys(data).forEach(key => {
            if (key !== 'temporal' && key !== 'spatial' && key !== 'semantic' && key !== 'logical' && key !== 'camera') {
                const nodeData = data[key];
                // Classify node based on type
                let nodeClass;
                if (nodeData.Action === "Exists" && 'Gender' in (nodeData?.Properties || {})) {
                    nodeClass = "entity actor";
                } else if (nodeData.Action === "Exists") {
                    nodeClass = "entity other";
                } else if (nodeData.Properties?.scene_type === "parent") {
                    nodeClass = "scene parent";
                } else if (nodeData.Properties?.scene_type === "leaf") {
                    nodeClass = "scene leaf";
                } else {
                    nodeClass = "event";
                }
                let detailsText = `id: ${key}\nAction: ${nodeData.Action}\nEntities: ${nodeData.Entities?.join(', ') || ''}\nLocation: ${nodeData.Location?.join(', ') || ''}`;

                if (Object.keys(nodeData.Properties || {}).length > 0) {
                    // For actor Exists nodes, only show Name and Gender
                    if (nodeClass.includes('actor')) {
                        const { Name, Gender } = nodeData.Properties;
                        detailsText += `\nName: ${Name}\nGender: ${Gender}`;
                    } else {
                        // For all other nodes, show full Properties
                        detailsText += `\nProperties: ${JSON.stringify(nodeData.Properties, null, 2)}`;
                    }
                }

                elements.push({
                    data: { id: key, label: key, details: detailsText },
                    classes: nodeClass
                });

                // Debug logging for actor nodes
                if (nodeClass.includes('actor')) {
                    console.log('Created actor node:', key, 'with classes:', nodeClass);
                }
            }
        });

        // PASS 2: Create all edges (same-entity relationships)
        Object.keys(data).forEach(key => {
            if (key !== 'temporal' && key !== 'spatial' && key !== 'semantic' && key !== 'logical' && key !== 'camera') {
                const nodeData = data[key];

                nodeData.Entities?.forEach(entity => {
                    // Create edge from this node to each entity it references
                    elements.push({
                        data: { source: key, target: entity, label: 'same-entity' },
                        classes: 'same-entity'
                    });
                });
            }
        });

        if (data.temporal) {
            const startingActions = data.temporal.starting_actions;

            Object.keys(startingActions).forEach(actorKey => {
                let temporalKey = startingActions[actorKey];
                let order = 0;
                while (temporalKey) {
                    const temporal = data.temporal[temporalKey];
                    if (temporal) {
                        if (temporal.next !== null) {
                            const source = temporalKey;
                            const target = temporal.next;
                            elements.push({ data: { source, target, label: 'next' }, classes: 'temporal' });
                        }
                        let eventNode = elements.find(e => e.data.id === temporalKey);
                        eventNode.data.order = order++;
                        eventNode.data.actor = actorKey;
                        if (temporal.relations !== null) {
                            temporal.relations.forEach(relationKey => {
                                const relation = data.temporal[relationKey];
                                if (relation?.source && relation?.target) {
                                    // Map "starts_with" to "same_time" for clarity
                                    const label = relation.type === 'starts_with' ? 'same_time' : relation.type;
                                    elements.push({
                                        data: { source: relation.source, target: relation.target, label: label },
                                        classes: 'temporal-relation'
                                    });
                                } else if (relation?.type === 'starts_with') {
                                    const source = temporalKey;
                                    const target = Object.keys(data.temporal).find(key => key !== source && data.temporal[key]?.relations?.includes(relationKey));

                                    if (target && !elements.find(e => e.data.source === target && e.data.target === source && e.data.label === 'same_time')) {
                                        elements.push({
                                            data: { source: source, target: target, label: 'same_time' },
                                            classes: 'temporal-relation'
                                        });
                                    }
                                }
                            });
                        }
                        temporalKey = temporal.next;
                    } else {
                        temporalKey = null;
                    }
                }
            });

            // Assign actor property to actor Exists nodes so they can be positioned
            console.log('Starting actions:', startingActions);
            console.log('Total elements:', elements.length);

            Object.keys(startingActions).forEach(actorKey => {
                console.log('Searching for actor:', actorKey);
                const actorExistsNode = elements.find(e => {
                    const match = e.data.id === actorKey && e.classes?.includes('actor');
                    if (e.data.id === actorKey) {
                        console.log('  Found element with id:', actorKey, 'classes:', e.classes, 'match:', match);
                    }
                    return match;
                });
                console.log('  Result:', actorExistsNode ? 'FOUND' : 'NOT FOUND');

                if (actorExistsNode) {
                    actorExistsNode.data.actor = actorKey;
                    actorExistsNode.data.order = -1; // Position at the top of the lane
                    console.log('  Assigned actor property to:', actorKey);
                }
            });
        }

        // Process semantic relations
        if (data.semantic) {
            Object.keys(data.semantic).forEach(key => {
                const semantic = data.semantic[key];

                // Create source node if it doesn't exist (for abstract semantic concepts)
                if (!elements.find(e => e.data.id === key)) {
                    elements.push({
                        data: {
                            id: key,
                            label: key,
                            details: `Semantic: ${semantic.type}`
                        },
                        classes: 'semantic-node'
                    });
                }

                // Create edges to targets
                if (semantic.type && semantic.targets) {
                    semantic.targets.forEach(target => {
                        // Verify target node exists before creating edge
                        if (elements.find(e => e.data.id === target)) {
                            elements.push({
                                data: {
                                    source: key,
                                    target: target,
                                    label: semantic.type
                                },
                                classes: 'semantic-relation'
                            });
                        } else {
                            console.warn(`[Semantic] Skipping edge: target '${target}' not found for source '${key}'`);
                        }
                    });
                }
            });
        }

        // Process logical relations
        if (data.logical) {
            Object.keys(data.logical).forEach(key => {
                const logical = data.logical[key];
                if (logical.type && logical.source && logical.target) {
                    elements.push({
                        data: {
                            source: logical.source,
                            target: logical.target,
                            label: logical.type
                        },
                        classes: 'logical-relation'
                    });
                }
            });
        }

        cy.add(elements);

        // In headless mode, we need to wait for layout to complete before exporting
        if (headlessConfig) {
            console.log('Headless mode: Waiting for layout to complete...');
            // Use adjustPositions which is synchronous, then export
            adjustPositions();

            // Small delay to ensure rendering is complete
            setTimeout(() => {
                performHeadlessExport();
            }, 1000);
        } else {
            // GUI mode - normal flow
            createToggleButtons();
            adjustPositions();
        }
    }

    function createToggleButtons() {
        toggleButtons.innerHTML = '';
        const nodeTypes = ['entity', 'actor', 'other', 'event', 'scene', 'parent', 'leaf'];
        nodeTypes.forEach(type => {
            const button = document.createElement('button');
            button.innerText = `Toggle ${type}`;
            button.addEventListener('click', () => {
                cy.nodes(`.${type}`).toggleClass('hidden');
            });
            toggleButtons.appendChild(button);
        });

        const edgeTypes = ['same-entity', 'temporal', 'temporal-relation', 'semantic-relation', 'logical-relation'];
        edgeTypes.forEach(type => {
            const button = document.createElement('button');
            button.innerText = `Toggle ${type}`;
            button.addEventListener('click', () => {
                cy.edges(`.${type}`).toggleClass('hidden');
            });
            toggleButtons.appendChild(button);
        });

        const button = document.createElement('button');
        button.innerText = 'Export as PNG';
        button.addEventListener('click', async () => {
            const png = cy.png({ full: true });
            const filePath = await ipcRenderer.invoke('save-file-dialog');
            if (filePath) {
            fs.writeFile(filePath, png.split(',')[1], 'base64', (err) => {
                if (err) {
                console.error('Error saving file:', err);
                } else {
                console.log('File saved successfully');
                }
            });
            }
        });
        toggleButtons.appendChild(button);
    }

    // After the layout is applied, manually adjust the positions
    function adjustPositions() {
        const nodes = cy.nodes();
        console.log('adjustPositions: Total nodes:', nodes.length);

        const groupedNodes = nodes.reduce((acc, node) => {
            const actor = node.data('actor');
            if (!acc[actor]) {
                acc[actor] = [];
            }
            acc[actor].push(node);
            return acc;
        }, {});

        console.log('Grouped by actor:', Object.keys(groupedNodes));
        console.log('Nodes per actor:', Object.fromEntries(
            Object.entries(groupedNodes).map(([k, v]) => [k, v.length])
        ));

        // Debug: Check actor entity nodes specifically
        Object.keys(groupedNodes).forEach(actorKey => {
            if (actorKey !== 'undefined') {
                const actorEntityNode = groupedNodes[actorKey].find(n => n.data('order') === -1);
                if (actorEntityNode) {
                    console.log(`Actor entity node "${actorKey}":`, {
                        id: actorEntityNode.id(),
                        classes: actorEntityNode.classes(),
                        hasActorClass: actorEntityNode.hasClass('actor'),
                        visible: actorEntityNode.visible(),
                        position: actorEntityNode.position()
                    });
                } else {
                    console.warn(`No entity node found for actor "${actorKey}" (no node with order=-1)`);
                }
            }
        });

        let xOffset = 0;
        Object.keys(groupedNodes).forEach((actor, actorIdx) => {
            const actorNodes = groupedNodes[actor];
            actorNodes.sort((a, b) => a.data('order') - b.data('order'));

            actorNodes.forEach((node, index) => {
                node.position({
                    y: index * 100,
                    x: actorIdx * 300
                });
            });

            xOffset += actorNodes.length * 100 + 100; // Adjust spacing between clusters
        });

        console.log('Calling cy.fit() to adjust viewport...');
        cy.fit(); // Adjust the viewport to fit the new positions
        console.log('Viewport adjusted. Zoom:', cy.zoom(), 'Pan:', cy.pan());
    }

    // Headless mode: automatically export PNG and exit
    function performHeadlessExport() {
        try {
            console.log('Headless mode: Generating PNG...');

            // Generate PNG with high quality settings
            const png = cy.png({
                full: true,  // Export entire graph, not just viewport
                scale: 2,    // 2x resolution for better quality
                bg: 'white'  // White background
            });

            // Write PNG to file
            const base64Data = png.split(',')[1];
            fs.writeFile(headlessConfig.outputPath, base64Data, 'base64', (err) => {
                if (err) {
                    console.error('Error saving PNG:', err);
                    ipcRenderer.send('export-error', err.message);
                } else {
                    console.log('Headless mode: PNG saved successfully');
                    ipcRenderer.send('export-complete', headlessConfig.outputPath);
                }
            });
        } catch (error) {
            console.error('Error during export:', error);
            ipcRenderer.send('export-error', error.message);
        }
    }
});

