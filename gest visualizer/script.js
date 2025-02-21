const { ipcRenderer } = require('electron');
const fs = require('fs');

document.addEventListener('DOMContentLoaded', () => {
    const dropzone = document.getElementById('dropzone');
    const cyContainer = document.getElementById('cy');
    const toggleButtons = document.getElementById('toggle-buttons');

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

    function loadGraph(filePath) {
        fs.readFile(filePath, 'utf-8', (err, data) => {
            if (err) {
                console.error('Error reading file:', err);
                return;
            }
            try {
                const graphData = JSON.parse(data);
                renderGraph(graphData);
            } catch (error) {
                console.error('Invalid JSON format:', error);
            }
        });
    }

    function renderGraph(data) {
        cy.elements().remove();
        const elements = [];
        Object.keys(data).forEach(key => {
            if (key !== 'temporal') {
                const nodeData = data[key];
                const nodeClass = nodeData.Action === "Exists" && 'Gender' in (nodeData?.Properties || {}) ? "entity actor" : nodeData.Action === "Exists" ? "entity other" : "event";
                let detailsText = `id: ${key}\nAction: ${nodeData.Action}\nEntities: ${nodeData.Entities?.join(', ') || ''}\nLocation: ${nodeData.Location?.join(', ') || ''}`;
                if (Object.keys(nodeData.Properties).length > 0)
                    detailsText += `\nProperties: ${JSON.stringify(nodeData.Properties, null, 2)}`

                elements.push({
                    data: { id: key, label: key, details: detailsText },
                    classes: nodeClass
                });

                nodeData.Entities?.forEach(entity => {
                    if (!cy.getElementById(entity).length) {
                        elements.push({ data: { id: entity, label: entity }, classes: "entity" });
                    }
                    elements.push({ data: { source: key, target: entity, label: 'same-entity' }, classes: 'same-entity' });
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
                                    elements.push({
                                        data: { source: relation.source, target: relation.target, label: relation.type },
                                        classes: 'temporal-relation'
                                    });
                                } else if (relation?.type === 'starts_with') {
                                    const source = temporalKey;
                                    const target = Object.keys(data.temporal).find(key => key !== source && data.temporal[key]?.relations?.includes(relationKey));

                                    if (target && !elements.find(e => e.data.source === target && e.data.target === source && e.data.label === relation.type)) {
                                        elements.push({
                                            data: { source: source, target: target, label: relation.type },
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
        }

        cy.add(elements);
        // cy.layout({ name: 'cose' }).run();
        createToggleButtons();
        adjustPositions();
    }

    function createToggleButtons() {
        toggleButtons.innerHTML = '';
        const nodeTypes = ['entity', 'actor', 'other', 'event'];
        nodeTypes.forEach(type => {
            const button = document.createElement('button');
            button.innerText = `Toggle ${type}`;
            button.addEventListener('click', () => {
                cy.nodes(`.${type}`).toggleClass('hidden');
            });
            toggleButtons.appendChild(button);
        });

        const edgeTypes = ['same-entity', 'temporal', 'temporal-relation'];
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
        const groupedNodes = nodes.reduce((acc, node) => {
            const actor = node.data('actor');
            if (!acc[actor]) {
                acc[actor] = [];
            }
            acc[actor].push(node);
            return acc;
        }, {});

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

        cy.fit(); // Adjust the viewport to fit the new positions
    }
});

