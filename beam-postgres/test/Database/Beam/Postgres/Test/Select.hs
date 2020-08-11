module Database.Beam.Postgres.Test.Select (tests) where

import           Data.Aeson
import           Data.ByteString (ByteString)
import           Data.Int
import           Data.Text (Text)
import qualified Data.Vector as V
import           Test.Tasty
import           Test.Tasty.HUnit
import           Data.UUID (UUID, nil)

import           Database.Beam
import           Database.Beam.Migrate
import           Database.Beam.Postgres
import           Database.Beam.Postgres.Extensions.UuidOssp

import           Database.Beam.Postgres.Test

tests :: IO ByteString -> TestTree
tests getConn = testGroup "Selection Tests"
  [ testGroup "JSON"
      [ testPgArrayToJSON getConn
      ]
  , testGroup "UUID"
      [ testUuidFunction getConn "uuid_nil" pgUuidNil
      , testUuidFunction getConn "uuid_ns_dns" pgUuidNsDns
      , testUuidFunction getConn "uuid_ns_url" pgUuidNsUrl
      , testUuidFunction getConn "uuid_ns_oid" pgUuidNsOid
      , testUuidFunction getConn "uuid_ns_x500" pgUuidNsX500
      , testUuidFunction getConn "uuid_generate_v1" pgUuidGenerateV1
      , testUuidFunction getConn "uuid_generate_v1mc" pgUuidGenerateV1Mc
      , testUuidFunction getConn "uuid_generate_v3" $ \ext ->
          pgUuidGenerateV3 ext (val_ nil) "nil"
      , testUuidFunction getConn "uuid_generate_v4" pgUuidGenerateV4
      , testUuidFunction getConn "uuid_generate_v5" $ \ext ->
          pgUuidGenerateV5 ext (val_ nil) "nil"
      ]
  ]

testPgArrayToJSON :: IO ByteString -> TestTree
testPgArrayToJSON getConn = testFunction getConn "array_to_json" $ \conn -> do
  let values :: [Int32] = [1, 2, 3]
  actual :: [PgJSON Value] <-
    runBeamPostgres conn $ runSelectReturningList $ select $
      return $ pgArrayToJson $ val_ $ V.fromList values
  assertEqual "JSON list" [PgJSON $ toJSON values] actual

data UuidSchema f = UuidSchema
  { _uuidOssp :: f (PgExtensionEntity UuidOssp)
  } deriving (Generic, Database Postgres)

testUuidFunction
  :: IO ByteString
  -> String
  -> (forall s. UuidOssp -> QExpr Postgres s UUID)
  -> TestTree
testUuidFunction getConn name mkUuid = testFunction getConn name $ \conn ->
  runBeamPostgres conn $ do
    db <- executeMigration runNoReturn $ UuidSchema <$>
      pgCreateExtension @UuidOssp
    [_] <- runSelectReturningList $ select $
      return $ mkUuid $ getPgExtension $ _uuidOssp $ unCheckDatabase db
    return ()

testFunction :: IO ByteString -> String -> (Connection -> Assertion) -> TestTree
testFunction getConn name mkAssertion = testCase name $
  withTestPostgres name getConn mkAssertion
