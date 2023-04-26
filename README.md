# SubQuery/Fetch.ai Indexer Workshop Example


Pre-requisites:
- [Fetchd](https://github.com/fetchai/fetchd)
- [Node](https://nodejs.org/en/download/package-manager)
- [NPM](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)
- [Yarn](https://classic.yarnpkg.com/lang/en/docs/install/#debian-stable)
- [Jenesis](https://docs.fetch.ai/Jenesis/)
- [Typescript](https://www.typescriptlang.org/)
- [Docker](https://docs.docker.com/engine/install/)

### Defining the NFT Entity
###### In `schema.graphql`:

Here we are implementing the outline for NFT entities to be indexed and for instances to be added to the database.

After running `yarn codegen` it will generate the schema for this entity.

```graphql
type NFT @entity {
  id: ID!
  owner: String!
  uri: String!
}
```

### Handling NFT Entities
###### In `src/mappings/mappingHandlers.ts`:
In order to populate the database these `NFT` entities, we must have a way of constructing them from incoming on-chain data.

```typescript
/* In this first section, you can see that we are passing a CosmosEvent into the function,
   which we are then dissecting to get a reference to the related NFT Mint message */

export async function handleNFTMint(event: CosmosEvent): Promise<void> {
  logger.info(`[NFT Mint Handled]`);
  const event_msg = event.msg?.msg?.decodedMsg;
  const mint_msg = event_msg?.msg?.mint;
  
// Here we are deconstructing the mint message into its components
  const id = mint_msg.token_id;
  const owner = mint_msg.owner;
  const uri = mint_msg.token_uri;
  
// Next, we take these component values and plug them into our new NFT, and save it
  const nftEntity = NFT.create({
    id,
    owner,
    uri
  });
  await nftEntity.save();
}
```

**N.B:** Don't forget to import the NFT type from schema.graphql:
```typescript
import {NFT} from "../types";
```

### Trigger the Handler Function
###### In `project.yaml`
Now that we have an `NFT` schema, and a handler to construct one, we need to be able to recognise when an NFT Mint event occurs and to pass our handler the correct on-chain data.
Which in this case, is an Event.

```yaml
handlers:
  - handler: handleNFTMint    # Here we reference our handler function
    kind: cosmos/EventHandler # We are looking for Cosmos events
    filter:
      type: "execute"         # Filtering for 'execute' events or contract executions
      messageFilter:          # Looking at the related message to the event
        type: "/cosmwasm.wasm.v1.MsgExecuteContract"
        contractCall: "mint"  # We are looking for contract executions that call 'mint'
```

In `project.yaml`, we can also configure which network we would like to index:
```yaml 
# Local Node
endpoint: http://fetch-node:26657
chainId: fetchchain
startBlock: 1
```  
Other network info can be found [here](https://docs.fetch.ai/ledger_v2/live-networks/), such as Mainnet and Dorado testnet.

### Running the Indexer

In order to reflect our changes, a number of commands have to be run. Which, in this example, have been compiled into a yarn script, `yarn dev`.

`yarn dev` is comprised of several commands:
- `docker compose down -v` - make sure any previous docker containers are not running
- `sudo rm -rf .data/` - wipe the locally stored database
- `subql codegen` - generate entity types from the schema
- `subql build` - compile the `@subql` environment
- `docker compose pull` - pull the latest docker images
- `docker compose up -d --remove-orphans` - spin up all containers 

`yarn log` should then be called to output the logs of our indexer.

### Jenesis Contract Management
A great way to deploy and manage contracts is to use the Fetch.ai tool, [Jenesis](https://docs.fetch.ai/Jenesis/). In this example, we'll use this tool to deploy and execute an NFT contract to test out our new indexer coverage.

The configuration for Jenesis has already been completed within this example repo - however, if you would like to learn how this was constructed, all information should be in the link above.

All of this config can be viewed or edited within the `jenesis.toml` file.

##### Setting up a test account & admin
In order to deploy anything to our local network, we need to have some currency on a test account. 

In the `docker-compose.yml` file, there is a fetch network node configured with a validator account. However, we need access to that account to use it - so we recover the account to our local testing keyring in order to leverage it.
```shell
fetchd config keyring-backend test

fetchd keys add validator --recover
```
After running the recovery command, we input the validator's mnemonic:

`nut grocery slice visit barrel peanut tumble patch slim logic install evidence fiction shield rich brown around arrest fresh position animal butter forget cost`

This can also be found in the `docker-compose.yml`.

**N.B** Ensure the keyring-backend variable value is the same as that set in the `jenesis.toml`, in this case the value is `test`.

##### Deploying the NFT contract
Now that we have an account with coins on our network, we need to compile our contract. 
```shell
jenesis compile
```
After this we need to store the contract on-chain, in order to be able to call execution messages on it later.
```shell
jenesis deploy validator
```
This command should come back with a green tick to say that our contract has been deployed successfully.

##### Minting our NFT
Minting the NFT requires us to construct a contract execution message in the custom Jenesis shell:
```shell
jenesis shell
```
Here we put together the pieces of our mint message, providing a URI, as well as who owns it, and its ID.
After this, we pass all of those into an execution command in the shell, and we deploy it from our `validator` account.

```python
URI = {
    "NFT info": "Some information about our NFT",
    "image_URL": "your_url_here"
}

mint_msg = {
    'mint': {
        'token_id': '1-2-3',
        'owner': 'fetch1wurz7uwmvchhc8x0yztc7220hxs9jxdjdsrqmn',
        'token_uri': str(URI)
    }
}

workshopNFT.execute(mint_msg, wallets['validator'])
```

**N.B** ensure that the URI is passed as a string.

After this, we should have a print message in the output log for our indexer that says `[NFT Mint Handled]`.
This means our indexer has recognised the NFT mint event, as well as constructed and saved our `NFT` entity.

#### Querying the NFT Entity
By visiting [http://localhost:3000/](http://localhost:3000/), we should be greeted with a GraphQL playground.
Here we can query any entities that have been indexed.

In order to look specifically at our NFT entity, we can run this query, and we should see an output of all the entity information that we request in the query: `id`, `owner` and `URI`.
```graphql
query NFTs {
  nFTs {
    nodes {
      id
      owner
      uri
    }
  }
}
```


---
#### Useful Resources

- [Fetch.ai Docs](https://docs.fetch.ai/)
- [SubQuery Documentation](https://academy.subquery.network/)
- [Tips and Tricks for Performance Improvements](https://academy.subquery.network/faqs/faqs.html#how-can-i-optimise-my-project-to-speed-it-up)
- [Automated Historical State tracking](https://academy.subquery.network/th/run_publish/historical.html)
- [GraphQL Subscriptions](https://academy.subquery.network/run_publish/subscription.html)
- [Discord with Technical Support Channel](https://discord.com/invite/subquery)
