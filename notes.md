# Notes for the presentation

## Setup

```bash
azd up
cat <<EOF > .env
export AI_FOUNDRY_PROJECT_ENDPOINT="$(azd env get-value AI_FOUNDRY_PROJECT_CONNECTION_STRING)"
export AI_FOUNDRY_ENDPOINT="$(azd env get-value AI_FOUNDRY_ENDPOINT)"
EOF
```

## Demo 1 : Azure AI Foundry Agent Service in Azure AI Foundry Portal

```text
This agent is activated when called by name the user asks for him or if his skills are useful to the conversation.
```

## Demo 2 : Azure AI Foindry Agent Service in Semantic Kernel


