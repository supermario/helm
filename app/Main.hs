module Main where

import           TextShow
import           Data.Monoid        ((<>))
import qualified Hilt
import qualified Hilt.Server       as Server
import qualified Hilt.Channel      as Channel
import qualified Hilt.Logger       as Logger
import qualified Hilt.SocketServer as Websocket
import           Network.Wai        (responseLBS)
import           Network.HTTP.Types (status200)

{-
To run this sample locally:

```
git clone git@github.com:supermario/hilt.git
cd hilt && stack build && stack exec hilt-example

# In another terminal window
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" localhost:8081
```

The Hilt.Postgres service is not demonstrated as it needs an existing Postgres DB in the DATABASE_URL ENV var,
and table to query. The addition is simple however if you want it:

  -- Add the db service next to the other services
  db <- Hilt.Postgres.load

  -- Use the handle within your program
  Hilt.Postgres.query db "SELECT * FROM myTable WHERE x = ?" ["1"]

-}
main :: IO ()
main = Hilt.manage $ do

  logger <- Logger.load
  chan   <- Channel.load

  let
    onJoined :: Websocket.OnJoined
    onJoined clientId clientCount = do
      Logger.debug logger $ showt clientId <> " joined, " <> showt clientCount <> " connected."
      return $ Just "Hello client!"

    onReceive :: Websocket.OnReceive
    onReceive clientId text = do
      Logger.debug logger $ showt clientId <> " said " <> showt text
      Channel.write chan text


  let application _ respond = respond $
          responseLBS status200 [("Content-Type", "text/plain")] "Hello World"


  websocket <- Websocket.load onJoined onReceive


  -- Now we can write our business logic using our services
  Hilt.program $ do
    Logger.debug logger "Starting up!"

    -- Log all messages received, then broadcast back to all clients
    Channel.worker chan (\text -> do
        Logger.debug logger ("[worker] got " <> text)
        Websocket.broadcast websocket text
      )

    Channel.write chan "Hello world!"

    -- Or pass services off to some other areas of your app
    -- someMoreLogic logger chan

    Server.runHttp application
