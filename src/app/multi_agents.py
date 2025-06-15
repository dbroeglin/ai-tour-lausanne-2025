import asyncio
import os
from pathlib import Path

import yaml
from azure.ai.agents import AgentsClient
from azure.ai.agents.models import CodeInterpreterTool
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv
from rich.console import Console
from rich.markup import escape
from rich.panel import Panel
from semantic_kernel.agents import (
    AgentGroupChat,
    AzureAIAgent,
    AzureAIAgentSettings,
    AzureAIAgentThread,
    AzureAIAgent,
)
from semantic_kernel.agents.strategies import KernelFunctionSelectionStrategy
from semantic_kernel.agents.strategies.termination.termination_strategy import (
    TerminationStrategy,
)

from semantic_kernel.agents import GroupChatManager, BooleanResult, StringResult, MessageResult
from semantic_kernel.contents import ChatMessageContent, ChatHistory

from semantic_kernel.kernel import Kernel

from semantic_kernel.agents import GroupChatOrchestration, RoundRobinGroupChatManager
from semantic_kernel.contents import ChatMessageContent

from semantic_kernel.agents.runtime import InProcessRuntime

load_dotenv()
console = Console()

import logging
from rich.logging import RichHandler
# logging.basicConfig(
#     level=logging.DEBUG,
#     format="%(message)s",
#     datefmt="[%X]",
#     handlers=[RichHandler(rich_tracebacks=True)],
# )
   
def agent_response_callback(message: ChatMessageContent) -> None:
    #console.print(f"[bold yellow]{message.name}[/]\n[cyan]{escape(message.content)}[/]")
    console.print(Panel(title=message.name, renderable=escape(message.content), title_align="left"))

client = AzureAIAgent.create_client(
    credential=DefaultAzureCredential(),
    endpoint=os.environ["AI_FOUNDRY_PROJECT_ENDPOINT"],
)

async def run(client):
    agents = [
        AzureAIAgent(
            client=client,
            definition=agent_definition,
            # plugins=[MenuPlugin()],  # add the sample plugin to the agent
        )
        async for agent_definition in client.agents.list_agents()
        if agent_definition.name in ["Airagorn", "Gandaif"]
    ]

    group_chat_orchestration = GroupChatOrchestration(
        members=agents,
        manager=RoundRobinGroupChatManager(max_rounds=5),
        agent_response_callback=agent_response_callback,

    )

    runtime = InProcessRuntime()
    runtime.start()
    orchestration_result = await group_chat_orchestration.invoke(
        task=(
            "Plan a route to destroy the One Ring. "
            "IMPORTANT: **The 5th and final speaker should decide and summarize the plan.**"),
        runtime=runtime,
    )

    # access the kernel here so that we can call a semantic kernel function
    runtime.

    value = await orchestration_result.get()
    console.print(Panel(title="[cyan]Final Result[/]", renderable=escape(value.content), title_align="left", ))

    await runtime.stop_when_idle()

asyncio.run(run(client))
