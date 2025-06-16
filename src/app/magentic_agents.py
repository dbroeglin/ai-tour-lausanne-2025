import asyncio
import os

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv
from rich.console import Console
from rich.markdown import Markdown
from rich.markup import escape
from rich.panel import Panel
from semantic_kernel.agents import (
    AzureAIAgent,
    MagenticOrchestration,
    StandardMagenticManager,
)
from semantic_kernel.agents.runtime import InProcessRuntime
from semantic_kernel.connectors.ai.open_ai import OpenAIChatCompletion
from semantic_kernel.contents import ChatMessageContent

load_dotenv()
console = Console()

# Uncomment the following lines to enable rich logging
# import logging
# from rich.logging import RichHandler
# logging.basicConfig(
#     level=logging.DEBUG,
#     format="%(message)s",
#     datefmt="[%X]",
#     handlers=[RichHandler(rich_tracebacks=True)],
# )
# logging.getLogger("azure.identity").setLevel(logging.WARNING)


def agent_response_callback(message: ChatMessageContent) -> None:
    console.print(
        Panel(
            title=message.name,
            renderable=Markdown(escape(message.content)),
            title_align="left",
        )
    )


client = AzureAIAgent.create_client(
    endpoint=os.environ["AI_FOUNDRY_PROJECT_ENDPOINT"],
    credential=DefaultAzureCredential(),
)


async def run(client: AIProjectClient):
    agents = [
        AzureAIAgent(
            client=client,
            definition=agent_definition,
            # plugins=[MenuPlugin()],  # add the sample plugin to the agent
        )
        async for agent_definition in client.agents.list_agents()
        if agent_definition.name in ["Airagorn", "Gandaif", "Merrai"]
    ]

    magentic_orchestration = MagenticOrchestration(
        members=agents,
        manager=StandardMagenticManager(
            chat_completion_service=OpenAIChatCompletion(
                ai_model_id="gpt-4.1-mini-2025-04-14",
                async_client=await client.inference.get_azure_openai_client(
                    api_version="2025-01-01-preview",
                ),
            )
        ),
        agent_response_callback=agent_response_callback,
    )

    runtime = InProcessRuntime()
    runtime.start()
    orchestration_result = await magentic_orchestration.invoke(
        task=(
            "Plan a route to destroy the One Ring. Leverage the strengths of each agent "
            "Provide a detailed plan with calculations about how long it will take and how "
            " much provisions to pack. Make all the necessary assumptions. "
            "The fellowship consists of 9 members: Frodo, Sam, Merry, Pippin, Aragorn, "
            "Legolas, Gimli, Boromir, and Gandalf. "
        ),
        runtime=runtime,
    )

    value = await orchestration_result.get()
    console.print(
        Panel(
            title="[cyan]Final Result[/]",
            renderable=Markdown(escape(value.content)),
            title_align="left",
        )
    )

    await runtime.stop_when_idle()


asyncio.run(run(client))
