import chainlit as cl
from semantic_kernel.connectors.ai import FunctionChoiceBehavior
from semantic_kernel.connectors.ai.open_ai import (
    OpenAIChatCompletion,
    OpenAIChatPromptExecutionSettings,
)

import os

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from semantic_kernel.agents import (
    AzureAIAgent,
    MagenticOrchestration,
    StandardMagenticManager,
)
from semantic_kernel.agents.runtime import InProcessRuntime
from semantic_kernel.contents import StreamingChatMessageContent


request_settings = OpenAIChatPromptExecutionSettings(
    function_choice_behavior=FunctionChoiceBehavior.Auto(
        filters={"excluded_plugins": ["ChatBot"]}
    )
)


@cl.on_chat_start
async def on_chat_start():
    client = AzureAIAgent.create_client(
        endpoint=os.environ["AI_FOUNDRY_PROJECT_ENDPOINT"],
        credential=DefaultAzureCredential(),
    )

    cl.user_session.set("client", client)


@cl.on_message
async def on_message(message: cl.Message):
    answer = cl.Message(content="")

    async def agent_response_callback(message: StreamingChatMessageContent) -> None:
        print(f"--------------------------- {message.name} -------------------------")
        async with cl.Step(name=message.name) as step:
            step.output = message.content

    client: AIProjectClient = cl.user_session.get("client")  # type: sk.Kernel
    agents = [
        AzureAIAgent(
            client=client,
            definition=agent_definition,
            # plugins=[MenuPlugin()],  # add the sample plugin to the agent
        )
        async for agent_definition in client.agents.list_agents()
        if agent_definition.name in ["Airagorn", "Gandaif", "Merrai"]
    ]

    print(f"Agents found: {[agent.name for agent in agents]}")
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

    runtime = InProcessRuntime(ignore_unhandled_exceptions=False)
    cl.user_session.set("runtime", runtime)

    runtime.start()
    orchestration_result = await magentic_orchestration.invoke(
        task=message.content,
        runtime=runtime,
    )

    value = await orchestration_result.get()
    await answer.stream_token(value.content)
    await answer.update()


@cl.on_chat_end
async def on_app_shutdown():
    runtime: InProcessRuntime = cl.user_session.get("runtime")
    if runtime:
        await runtime.stop_when_idle()


@cl.set_starters
async def set_starters():
    return [
        cl.Starter(
            label="Plan a route to destroy the One Ring",
            message=(
                "Plan a route to destroy the One Ring. Leverage the strengths of each member "
                " of the fellowship you can use in the conversation. "
                "Ask every agent of the team at least once. "
                "Provide a detailed plan with calculations about how long it will take and how "
                " much provisions to pack. Make all the necessary assumptions. Merry can do the "
                " calculations. "
                "The fellowship consists of 9 members: Frodo, Sam, Merry, Pippin, Aragorn, Legolas, "
                "Gimli, Boromir, and Gandalf. "
            ),
        ),
    ]
