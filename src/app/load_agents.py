import os
from pathlib import Path

import yaml
from azure.ai.agents import AgentsClient
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv
from rich.console import Console

load_dotenv()
console = Console()

agents_client = AgentsClient(
    endpoint=os.environ["AI_FOUNDRY_PROJECT_ENDPOINT"],
    credential=DefaultAzureCredential(),
)

agents = {}
for agent in agents_client.list_agents():
    agents[agent.name] = agent

# Delete all existing agents (uncomment if you want to clear existing agents)
# for agent in agents.values():
#     console.print(        f"Deleting agent [bold cyan]{agent.name}[/]"    )
#     agents_client.delete_agent(agent.id)
# agents = {}

for spec in Path("agents").glob("*.yaml"):
    with open(spec, "r") as f:
        agent_spec = yaml.safe_load(f)
    if agent_spec["name"] not in agents:
        console.print(
            f"Creating agent: [bold cyan]{agent_spec['name']}[/]- [dim]{agent_spec.get('description')}[/dim]..."
        )
        agents_client.create_agent(
            name=agent_spec["name"],
            model=agent_spec["model"],
            description=agent_spec.get("description"),
            instructions=agent_spec.get("instructions"),
        )
    else:
        console.print(
            f"Agent [bold cyan]{agent_spec['name']}[/] - [dim]{agent.description}[/dim] already exists, updating..."
        )
        for t in agents[agent_spec["name"]].tools:
            console.print(f"  - Tool: [bold cyan]{t}[/]")
        agents_client.update_agent(
            agent_id=agents[agent_spec["name"]].id,
            name=agent_spec["name"],
            model=agent_spec["model"],
            description=agent_spec.get("description"),
            instructions=agent_spec.get("instructions"),
        )
