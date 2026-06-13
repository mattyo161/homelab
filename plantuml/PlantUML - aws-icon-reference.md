# AWS PlantUML Icon Reference

## Analytics

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Analytics/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Analytics")
$iconRow("Athena")
$iconRow("AthenaDataSourceConnectors")
$iconRow("CleanRooms")
$iconRow("CloudSearch")
$iconRow("CloudSearchSearchDocuments")
$iconRow("DataExchange")
$iconRow("DataExchangeforAPIs")
$iconRow("DataFirehose")
$iconRow("DataZone")
$iconRow("DataZoneBusinessDataCatalog")
$iconRow("DataZoneDataPortal")
$iconRow("DataZoneDataProjects")
$iconRow("EMR")
$iconRow("EMRCluster")
$iconRow("EMREMREngine")
$iconRow("EMRHDFSCluster")
$iconRow("EntityResolution")
$iconRow("FinSpace")
$iconRow("Glue")
$iconRow("GlueAWSGlueforRay")
$iconRow("GlueCrawler")
$iconRow("GlueDataBrew")
$iconRow("GlueDataCatalog")
$iconRow("GlueDataQuality")
$iconRow("Kinesis")
$iconRow("KinesisDataStreams")
$iconRow("KinesisVideoStreams")
$iconRow("LakeFormation")
$iconRow("LakeFormationDataLake")
$iconRow("MSKAmazonMSKConnect")
$iconRow("ManagedServiceforApacheFlink")
$iconRow("ManagedStreamingforApacheKafka")
$iconRow("OpenSearchService")
$iconRow("OpenSearchServiceClusterAdministratorNode")
$iconRow("OpenSearchServiceDataNode")
$iconRow("OpenSearchServiceIndex")
$iconRow("OpenSearchServiceObservability")
$iconRow("OpenSearchServiceOpenSearchDashboards")
$iconRow("OpenSearchServiceOpenSearchIngestion")
$iconRow("OpenSearchServiceTraces")
$iconRow("OpenSearchServiceUltraWarmNode")
$iconRow("Redshift")
$iconRow("RedshiftAutocopy")
$iconRow("RedshiftDataSharingGovernance")
$iconRow("RedshiftDenseComputeNode")
$iconRow("RedshiftDenseStorageNode")
$iconRow("RedshiftML")
$iconRow("RedshiftQueryEditorv20")
$iconRow("RedshiftRA3")
$iconRow("RedshiftStreamingIngestion")
$iconRow("SageMaker")
endlegend

@enduml
```

## ApplicationIntegration

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/ApplicationIntegration/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("AppFlow")
$iconRow("AppSync")
$iconRow("ApplicationIntegration")
$iconRow("B2BDataInterchange")
$iconRow("EventBridge")
$iconRow("EventBridgeCustomEventBus")
$iconRow("EventBridgeDefaultEventBus")
$iconRow("EventBridgeEvent")
$iconRow("EventBridgePipes")
$iconRow("EventBridgeRule")
$iconRow("EventBridgeSaasPartnerEvent")
$iconRow("EventBridgeScheduler")
$iconRow("EventBridgeSchema")
$iconRow("EventBridgeSchemaRegistry")
$iconRow("ExpressWorkflows")
$iconRow("MQ")
$iconRow("MQBroker")
$iconRow("ManagedWorkflowsforApacheAirflow")
$iconRow("SimpleNotificationService")
$iconRow("SimpleNotificationServiceEmailNotification")
$iconRow("SimpleNotificationServiceHTTPNotification")
$iconRow("SimpleNotificationServiceTopic")
$iconRow("SimpleQueueService")
$iconRow("SimpleQueueServiceMessage")
$iconRow("SimpleQueueServiceQueue")
$iconRow("StepFunctions")
endlegend

@enduml
```

## ArtificialIntelligence

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/ArtificialIntelligence/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("ApacheMXNetonAWS")
$iconRow("AppStudio")
$iconRow("ArtificialIntelligence")
$iconRow("AugmentedAIA2I")
$iconRow("Bedrock")
$iconRow("BedrockAgentCore")
$iconRow("CodeGuru")
$iconRow("CodeWhisperer")
$iconRow("Comprehend")
$iconRow("ComprehendMedical")
$iconRow("DeepLearningAMIs")
$iconRow("DeepLearningContainers")
$iconRow("DeepRacer")
$iconRow("DevOpsGuru")
$iconRow("DevOpsGuruInsights")
$iconRow("ElasticInference")
$iconRow("Forecast")
$iconRow("FraudDetector")
$iconRow("HealthImaging")
$iconRow("HealthLake")
$iconRow("HealthOmics")
$iconRow("HealthScribe")
$iconRow("Kendra")
$iconRow("Lex")
$iconRow("LookoutforEquipment")
$iconRow("LookoutforVision")
$iconRow("Monitron")
$iconRow("Neuron")
$iconRow("Nova")
$iconRow("Panorama")
$iconRow("Personalize")
$iconRow("Polly")
$iconRow("PyTorchonAWS")
$iconRow("Q")
$iconRow("Rekognition")
$iconRow("RekognitionImage")
$iconRow("RekognitionVideo")
$iconRow("SageMakerAI")
$iconRow("SageMakerAICanvas")
$iconRow("SageMakerAIGeospatialML")
$iconRow("SageMakerAIModel")
$iconRow("SageMakerAINotebook")
$iconRow("SageMakerAIShadowTesting")
$iconRow("SageMakerAITrain")
$iconRow("SageMakerGroundTruth")
$iconRow("SageMakerStudioLab")
$iconRow("TensorFlowonAWS")
$iconRow("Textract")
$iconRow("TextractAnalyzeLending")
$iconRow("Transcribe")
$iconRow("Translate")
endlegend

@enduml
```

## Blockchain

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Blockchain/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Blockchain")
$iconRow("ManagedBlockchain")
$iconRow("ManagedBlockchainBlockchain")
endlegend

@enduml
```

## BusinessApplications

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/BusinessApplications/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("AppFabric")
$iconRow("BusinessApplications")
$iconRow("Chime")
$iconRow("ChimeSDK")
$iconRow("Connect")
$iconRow("EndUserMessaging")
$iconRow("Pinpoint")
$iconRow("PinpointAPIs")
$iconRow("PinpointJourney")
$iconRow("QuickSuite")
$iconRow("SimpleEmailService")
$iconRow("SimpleEmailServiceEmail")
$iconRow("SupplyChain")
$iconRow("Wickr")
$iconRow("WorkDocs")
$iconRow("WorkDocsSDK")
$iconRow("WorkMail")
endlegend

@enduml
```

## CloudFinancialManagement

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/CloudFinancialManagement/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("BillingConductor")
$iconRow("Budgets")
$iconRow("CloudFinancialManagement")
$iconRow("CostExplorer")
$iconRow("CostandUsageReport")
$iconRow("ReservedInstanceReporting")
$iconRow("SavingsPlans")
endlegend

@enduml
```

## Compute

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Compute/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("AppRunner")
$iconRow("Batch")
$iconRow("Bottlerocket")
$iconRow("Compute")
$iconRow("ComputeOptimizer2")
$iconRow("DCV")
$iconRow("EC2")
$iconRow("EC2AMI")
$iconRow("EC2AWSMicroserviceExtractorforNET")
$iconRow("EC2AutoScaling")
$iconRow("EC2AutoScalingResource")
$iconRow("EC2DBInstance")
$iconRow("EC2ElasticIPAddress")
$iconRow("EC2ImageBuilder")
$iconRow("EC2Instance")
$iconRow("EC2Instances")
$iconRow("EC2InstancewithCloudWatch")
$iconRow("EC2Rescue")
$iconRow("EC2SpotInstance")
$iconRow("ElasticBeanstalk")
$iconRow("ElasticBeanstalkApplication")
$iconRow("ElasticBeanstalkDeployment")
$iconRow("ElasticFabricAdapter")
$iconRow("ElasticVMwareService")
$iconRow("Lambda")
$iconRow("LambdaLambdaFunction")
$iconRow("Lightsail")
$iconRow("LightsailforResearch")
$iconRow("LocalZones")
$iconRow("NitroEnclaves")
$iconRow("Outpostsfamily")
$iconRow("Outpostsrack")
$iconRow("Outpostsservers")
$iconRow("ParallelCluster")
$iconRow("ParallelComputingService")
$iconRow("ServerlessApplicationRepository")
$iconRow("SimSpaceWeaver")
$iconRow("Wavelength")
endlegend

@enduml
```

## Containers

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Containers/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Containers")
$iconRow("ECSAnywhere")
$iconRow("EKSAnywhere")
$iconRow("EKSDistro")
$iconRow("ElasticContainerRegistry")
$iconRow("ElasticContainerRegistryImage")
$iconRow("ElasticContainerRegistryRegistry")
$iconRow("ElasticContainerService")
$iconRow("ElasticContainerServiceContainer1")
$iconRow("ElasticContainerServiceContainer2")
$iconRow("ElasticContainerServiceContainer3")
$iconRow("ElasticContainerServiceCopilotCLI")
$iconRow("ElasticContainerServiceECSServiceConnect")
$iconRow("ElasticContainerServiceService")
$iconRow("ElasticContainerServiceTask")
$iconRow("ElasticKubernetesService")
$iconRow("ElasticKubernetesServiceEKSonOutposts")
$iconRow("Fargate")
$iconRow("RedHatOpenShiftServiceonAWS")
endlegend

@enduml
```

## CustomerEnablement

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/CustomerEnablement/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Activate")
$iconRow("CustomerEnablement")
$iconRow("IQ")
$iconRow("ManagedServices")
$iconRow("ProfessionalServices")
$iconRow("Support")
$iconRow("TrainingCertification")
$iconRow("rePost")
$iconRow("rePostPrivate")
endlegend

@enduml
```

## CustomerExperience

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/CustomerExperience/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("CustomerExperience")
endlegend

@enduml
```

## Database

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Database/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Aurora")
$iconRow("AuroraAmazonAuroraInstanceAlternate")
$iconRow("AuroraAmazonRDSInstance")
$iconRow("AuroraAmazonRDSInstanceAlternate")
$iconRow("AuroraInstance")
$iconRow("AuroraMariaDBInstance")
$iconRow("AuroraMariaDBInstanceAlternate")
$iconRow("AuroraMySQLInstance")
$iconRow("AuroraMySQLInstanceAlternate")
$iconRow("AuroraOracleInstance")
$iconRow("AuroraOracleInstanceAlternate")
$iconRow("AuroraPIOPSInstance")
$iconRow("AuroraPostgreSQLInstance")
$iconRow("AuroraPostgreSQLInstanceAlternate")
$iconRow("AuroraSQLServerInstance")
$iconRow("AuroraSQLServerInstanceAlternate")
$iconRow("AuroraTrustedLanguageExtensionsforPostgreSQL")
$iconRow("Database")
$iconRow("DatabaseMigrationService")
$iconRow("DatabaseMigrationServiceDatabasemigrationworkflowjob")
$iconRow("DocumentDB")
$iconRow("DocumentDBElasticClusters")
$iconRow("DynamoDB")
$iconRow("DynamoDBAmazonDynamoDBAccelerator")
$iconRow("DynamoDBAttribute")
$iconRow("DynamoDBAttributes")
$iconRow("DynamoDBGlobalsecondaryindex")
$iconRow("DynamoDBItem")
$iconRow("DynamoDBItems")
$iconRow("DynamoDBStandardAccessTableClass")
$iconRow("DynamoDBStandardInfrequentAccessTableClass")
$iconRow("DynamoDBStream")
$iconRow("DynamoDBTable")
$iconRow("ElastiCache")
$iconRow("ElastiCacheCacheNode")
$iconRow("ElastiCacheElastiCacheforMemcached")
$iconRow("ElastiCacheElastiCacheforRedis")
$iconRow("ElastiCacheElastiCacheforValkey")
$iconRow("Keyspaces")
$iconRow("MemoryDB")
$iconRow("Neptune")
$iconRow("OracleDatabaseatAWS")
$iconRow("RDS")
$iconRow("RDSBlueGreenDeployments")
$iconRow("RDSMultiAZ")
$iconRow("RDSMultiAZDBCluster")
$iconRow("RDSOptimizedWrites")
$iconRow("RDSProxyInstance")
$iconRow("RDSProxyInstanceAlternate")
$iconRow("RDSTrustedLanguageExtensionsforPostgreSQL")
$iconRow("Timestream")
endlegend

@enduml
```

## DeveloperTools

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/DeveloperTools/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Cloud9")
$iconRow("Cloud9Cloud9")
$iconRow("CloudControlAPI")
$iconRow("CloudDevelopmentKit")
$iconRow("CloudShell")
$iconRow("CodeArtifact")
$iconRow("CodeBuild")
$iconRow("CodeCatalyst")
$iconRow("CodeCommit")
$iconRow("CodeDeploy")
$iconRow("CodePipeline")
$iconRow("CommandLineInterface")
$iconRow("Corretto")
$iconRow("DeveloperTools")
$iconRow("FaultInjectionService")
$iconRow("InfrastructureComposer")
$iconRow("ToolsandSDKs")
$iconRow("XRay")
endlegend

@enduml
```

## EndUserComputing

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/EndUserComputing/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("EndUserComputing")
$iconRow("WorkSpaces")
endlegend

@enduml
```

## FrontEndWebMobile

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/FrontEndWebMobile/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Amplify")
$iconRow("AmplifyAWSAmplifyStudio")
$iconRow("DeviceFarm")
$iconRow("FrontEndWebMobile")
$iconRow("LocationService")
$iconRow("LocationServiceGeofence")
$iconRow("LocationServiceMap")
$iconRow("LocationServicePlace")
$iconRow("LocationServiceRoutes")
$iconRow("LocationServiceTrack")
endlegend

@enduml
```

## Games

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Games/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("GameLiftServers")
$iconRow("GameLiftStreams")
$iconRow("Games")
$iconRow("Open3DEngine")
endlegend

@enduml
```

## General

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/General/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("AWSManagementConsole")
$iconRow("Alert")
$iconRow("AuthenticatedUser")
$iconRow("Camera")
$iconRow("Chat")
$iconRow("Client")
$iconRow("ColdStorage")
$iconRow("Credentials")
$iconRow("DataStream")
$iconRow("DataTable")
$iconRow("Disk")
$iconRow("Document")
$iconRow("Documents")
$iconRow("Email")
$iconRow("Firewall")
$iconRow("Folder")
$iconRow("Folders")
$iconRow("Forums")
$iconRow("Gear")
$iconRow("GenericApplication")
$iconRow("Genericdatabase")
$iconRow("GitRepository")
$iconRow("Globe")
$iconRow("Internet")
$iconRow("Internetalt1")
$iconRow("Internetalt2")
$iconRow("JSONScript")
$iconRow("Logs")
$iconRow("MagnifyingGlass")
$iconRow("Marketplace")
$iconRow("Metrics")
$iconRow("Mobileclient")
$iconRow("Multimedia")
$iconRow("Officebuilding")
$iconRow("ProgrammingLanguage")
$iconRow("Question")
$iconRow("Recover")
$iconRow("SAMLtoken")
$iconRow("SDK")
$iconRow("SSLpadlock")
$iconRow("Servers")
$iconRow("Shield2")
$iconRow("SourceCode")
$iconRow("Tapestorage")
$iconRow("Toolkit")
$iconRow("Traditionalserver")
$iconRow("User")
$iconRow("Users")
endlegend

@enduml
```

## Groups

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Groups/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("AWSAccount")
$iconRow("AWSCloud")
$iconRow("AWSCloudAlt")
$iconRow("AutoScalingGroup")
$iconRow("AvailabilityZone")
$iconRow("CorporateDataCenter")
$iconRow("EC2InstanceContents")
$iconRow("ElasticBeanstalkContainer")
$iconRow("Generic")
$iconRow("GenericAlt")
$iconRow("GenericBlue")
$iconRow("GenericGreen")
$iconRow("GenericOrange")
$iconRow("GenericPink")
$iconRow("GenericPurple")
$iconRow("GenericRed")
$iconRow("GenericTurquoise")
$iconRow("IoTGreengrass")
$iconRow("IoTGreengrassDeployment")
$iconRow("PrivateSubnet")
$iconRow("PublicSubnet")
$iconRow("Region")
$iconRow("SecurityGroup")
$iconRow("ServerContents")
$iconRow("SpotFleet")
$iconRow("StepFunctionsWorkflow")
$iconRow("VPC")
endlegend

@enduml
```

## InternetOfThings

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/InternetOfThings/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("FreeRTOS")
$iconRow("InternetOfThings")
$iconRow("IoTAction")
$iconRow("IoTActuator")
$iconRow("IoTAlexaEnabledDevice")
$iconRow("IoTAlexaSkill")
$iconRow("IoTAlexaVoiceService")
$iconRow("IoTCertificate")
$iconRow("IoTCore")
$iconRow("IoTCoreDeviceAdvisor")
$iconRow("IoTCoreDeviceLocation")
$iconRow("IoTDesiredState")
$iconRow("IoTDeviceDefender")
$iconRow("IoTDeviceDefenderIoTDeviceJobs")
$iconRow("IoTDeviceGateway")
$iconRow("IoTDeviceManagement")
$iconRow("IoTDeviceManagementFleetHub")
$iconRow("IoTDeviceTester")
$iconRow("IoTEcho")
$iconRow("IoTEvents")
$iconRow("IoTExpressLink")
$iconRow("IoTFireTV")
$iconRow("IoTFireTVStick")
$iconRow("IoTFleetWise")
$iconRow("IoTGreengrass")
$iconRow("IoTGreengrassArtifact")
$iconRow("IoTGreengrassComponent")
$iconRow("IoTGreengrassComponentMachineLearning")
$iconRow("IoTGreengrassComponentNucleus")
$iconRow("IoTGreengrassComponentPrivate")
$iconRow("IoTGreengrassComponentPublic")
$iconRow("IoTGreengrassConnector")
$iconRow("IoTGreengrassInterprocessCommunication")
$iconRow("IoTGreengrassProtocol")
$iconRow("IoTGreengrassRecipe")
$iconRow("IoTGreengrassStreamManager")
$iconRow("IoTHTTP2Protocol")
$iconRow("IoTHTTPProtocol")
$iconRow("IoTHardwareBoard")
$iconRow("IoTLambdaFunction")
$iconRow("IoTLoRaWANProtocol")
$iconRow("IoTMQTTProtocol")
$iconRow("IoTOverAirUpdate")
$iconRow("IoTPolicy")
$iconRow("IoTReportedState")
$iconRow("IoTRule")
$iconRow("IoTSailboat")
$iconRow("IoTSensor")
$iconRow("IoTServo")
$iconRow("IoTShadow")
$iconRow("IoTSimulator")
$iconRow("IoTSiteWise")
$iconRow("IoTSiteWiseAsset")
$iconRow("IoTSiteWiseAssetHierarchy")
$iconRow("IoTSiteWiseAssetModel")
$iconRow("IoTSiteWiseAssetProperties")
$iconRow("IoTSiteWiseDataStreams")
$iconRow("IoTThingBank")
$iconRow("IoTThingBicycle")
$iconRow("IoTThingCamera")
$iconRow("IoTThingCar")
$iconRow("IoTThingCart")
$iconRow("IoTThingCoffeePot")
$iconRow("IoTThingDoorLock")
$iconRow("IoTThingFactory")
$iconRow("IoTThingFreeRTOSDevice")
$iconRow("IoTThingGeneric")
$iconRow("IoTThingHouse")
$iconRow("IoTThingHumiditySensor")
$iconRow("IoTThingIndustrialPC")
$iconRow("IoTThingLightbulb")
$iconRow("IoTThingMedicalEmergency")
$iconRow("IoTThingPLC")
$iconRow("IoTThingPoliceEmergency")
$iconRow("IoTThingRelay")
$iconRow("IoTThingStacklight")
$iconRow("IoTThingTemperatureHumiditySensor")
$iconRow("IoTThingTemperatureSensor")
$iconRow("IoTThingTemperatureVibrationSensor")
$iconRow("IoTThingThermostat")
$iconRow("IoTThingTravel")
$iconRow("IoTThingUtility")
$iconRow("IoTThingVibrationSensor")
$iconRow("IoTThingWindfarm")
$iconRow("IoTTopic")
$iconRow("IoTTwinMaker")
endlegend

@enduml
```

## ManagementGovernance

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/ManagementGovernance/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("AppConfig")
$iconRow("ApplicationAutoScaling2")
$iconRow("AutoScaling")
$iconRow("BackintAgent")
$iconRow("Chatbot")
$iconRow("CloudFormation")
$iconRow("CloudFormationChangeSet")
$iconRow("CloudFormationStack")
$iconRow("CloudFormationTemplate")
$iconRow("CloudTrail")
$iconRow("CloudTrailCloudTrailLake")
$iconRow("CloudWatch")
$iconRow("CloudWatchAlarm")
$iconRow("CloudWatchCrossaccountObservability")
$iconRow("CloudWatchDataProtection")
$iconRow("CloudWatchEventEventBased")
$iconRow("CloudWatchEventTimeBased")
$iconRow("CloudWatchEvidently")
$iconRow("CloudWatchLogs")
$iconRow("CloudWatchMetricsInsights")
$iconRow("CloudWatchRUM")
$iconRow("CloudWatchRule")
$iconRow("CloudWatchSynthetics")
$iconRow("ComputeOptimizer")
$iconRow("Config")
$iconRow("ConsoleMobileApplication")
$iconRow("ControlTower")
$iconRow("DevOpsAgent")
$iconRow("DistroforOpenTelemetry")
$iconRow("HealthDashboard")
$iconRow("LaunchWizard")
$iconRow("LicenseManager")
$iconRow("LicenseManagerApplicationDiscovery")
$iconRow("LicenseManagerLicenseBlending")
$iconRow("ManagedGrafana")
$iconRow("ManagedServiceforPrometheus")
$iconRow("ManagementConsole")
$iconRow("ManagementGovernance")
$iconRow("Organizations")
$iconRow("OrganizationsAccount")
$iconRow("OrganizationsManagementAccount")
$iconRow("OrganizationsOrganizationalUnit")
$iconRow("PartnerCentral")
$iconRow("Proton")
$iconRow("ResilienceHub")
$iconRow("ResourceExplorer")
$iconRow("ServiceCatalog")
$iconRow("ServiceManagementConnector")
$iconRow("SystemsManager")
$iconRow("SystemsManagerApplicationManager")
$iconRow("SystemsManagerAutomation")
$iconRow("SystemsManagerChangeCalendar")
$iconRow("SystemsManagerChangeManager")
$iconRow("SystemsManagerCompliance")
$iconRow("SystemsManagerDistributor")
$iconRow("SystemsManagerDocuments")
$iconRow("SystemsManagerIncidentManager")
$iconRow("SystemsManagerInventory")
$iconRow("SystemsManagerMaintenanceWindows")
$iconRow("SystemsManagerOpsCenter")
$iconRow("SystemsManagerParameterStore")
$iconRow("SystemsManagerPatchManager")
$iconRow("SystemsManagerRunCommand")
$iconRow("SystemsManagerSessionManager")
$iconRow("SystemsManagerStateManager")
$iconRow("TelcoNetworkBuilder")
$iconRow("TrustedAdvisor")
$iconRow("TrustedAdvisorChecklist")
$iconRow("TrustedAdvisorChecklistCost")
$iconRow("TrustedAdvisorChecklistFaultTolerant")
$iconRow("TrustedAdvisorChecklistPerformance")
$iconRow("TrustedAdvisorChecklistSecurity")
$iconRow("UserNotifications")
$iconRow("WellArchitectedTool")
endlegend

@enduml
```

## MediaServices

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/MediaServices/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("CloudDigitalInterface")
$iconRow("DeadlineCloud")
$iconRow("ElementalAppliancesSoftware")
$iconRow("ElementalConductor")
$iconRow("ElementalDelta")
$iconRow("ElementalLink")
$iconRow("ElementalLive")
$iconRow("ElementalMediaConnect")
$iconRow("ElementalMediaConnectMediaConnectGateway")
$iconRow("ElementalMediaConvert")
$iconRow("ElementalMediaLive")
$iconRow("ElementalMediaPackage")
$iconRow("ElementalMediaStore")
$iconRow("ElementalMediaTailor")
$iconRow("ElementalServer")
$iconRow("InteractiveVideoService")
$iconRow("KinesisVideoStreams2")
$iconRow("MediaServices")
$iconRow("ThinkboxDeadline")
$iconRow("ThinkboxFrost")
$iconRow("ThinkboxKrakatoa")
$iconRow("ThinkboxStoke")
$iconRow("ThinkboxXMesh")
endlegend

@enduml
```

## MigrationModernization

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/MigrationModernization/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("ApplicationDiscoveryService")
$iconRow("ApplicationDiscoveryServiceAWSAgentlessCollector")
$iconRow("ApplicationDiscoveryServiceAWSDiscoveryAgent")
$iconRow("ApplicationDiscoveryServiceMigrationEvaluatorCollector")
$iconRow("ApplicationMigrationService")
$iconRow("DataSync")
$iconRow("DataSyncDiscovery")
$iconRow("DataTransferTerminal")
$iconRow("DatasyncAgent")
$iconRow("MainframeModernization")
$iconRow("MainframeModernizationAnalyzer")
$iconRow("MainframeModernizationCompiler")
$iconRow("MainframeModernizationConverter")
$iconRow("MainframeModernizationDeveloper")
$iconRow("MainframeModernizationRuntime")
$iconRow("MigrationEvaluator")
$iconRow("MigrationHub")
$iconRow("MigrationHubRefactorSpacesApplications")
$iconRow("MigrationHubRefactorSpacesEnvironments")
$iconRow("MigrationHubRefactorSpacesServices")
$iconRow("MigrationModernization")
$iconRow("TransferFamily")
$iconRow("TransferFamilyAWSAS2")
$iconRow("TransferFamilyAWSFTP")
$iconRow("TransferFamilyAWSFTPS")
$iconRow("TransferFamilyAWSSFTP")
$iconRow("Transform")
endlegend

@enduml
```

## MulticloudandHybrid

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/MulticloudandHybrid/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("MulticloudandHybrid")
endlegend

@enduml
```

## NetworkingContentDelivery

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/NetworkingContentDelivery/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("APIGateway")
$iconRow("APIGatewayEndpoint")
$iconRow("AppMesh")
$iconRow("AppMeshMesh")
$iconRow("AppMeshVirtualGateway")
$iconRow("AppMeshVirtualNode")
$iconRow("AppMeshVirtualRouter")
$iconRow("AppMeshVirtualService")
$iconRow("ApplicationRecoveryController")
$iconRow("ClientVPN")
$iconRow("CloudFront")
$iconRow("CloudFrontDownloadDistribution")
$iconRow("CloudFrontEdgeLocation")
$iconRow("CloudFrontFunctions")
$iconRow("CloudFrontStreamingDistribution")
$iconRow("CloudMap")
$iconRow("CloudMapNamespace")
$iconRow("CloudMapResource")
$iconRow("CloudMapService")
$iconRow("CloudWAN")
$iconRow("CloudWANCoreNetworkEdge")
$iconRow("CloudWANSegmentNetwork")
$iconRow("CloudWANTransitGatewayRouteTableAttachment")
$iconRow("DirectConnect")
$iconRow("DirectConnectGateway")
$iconRow("ElasticLoadBalancing")
$iconRow("ElasticLoadBalancingApplicationLoadBalancer")
$iconRow("ElasticLoadBalancingClassicLoadBalancer")
$iconRow("ElasticLoadBalancingGatewayLoadBalancer")
$iconRow("ElasticLoadBalancingNetworkLoadBalancer")
$iconRow("GlobalAccelerator")
$iconRow("NetworkingContentDelivery")
$iconRow("PrivateLink")
$iconRow("RTBFabric")
$iconRow("Route53")
$iconRow("Route53HostedZone")
$iconRow("Route53ReadinessChecks")
$iconRow("Route53Resolver")
$iconRow("Route53ResolverDNSFirewall")
$iconRow("Route53ResolverQueryLogging")
$iconRow("Route53RouteTable")
$iconRow("Route53RoutingControls")
$iconRow("SitetoSiteVPN")
$iconRow("TransitGateway")
$iconRow("TransitGatewayAttachment")
$iconRow("VPCCarrierGateway")
$iconRow("VPCCustomerGateway")
$iconRow("VPCElasticNetworkAdapter")
$iconRow("VPCElasticNetworkInterface")
$iconRow("VPCEndpoints")
$iconRow("VPCFlowLogs")
$iconRow("VPCInternetGateway")
$iconRow("VPCLattice")
$iconRow("VPCNATGateway")
$iconRow("VPCNetworkAccessAnalyzer")
$iconRow("VPCNetworkAccessControlList")
$iconRow("VPCPeeringConnection")
$iconRow("VPCReachabilityAnalyzer")
$iconRow("VPCRouter")
$iconRow("VPCTrafficMirroring")
$iconRow("VPCVPNConnection")
$iconRow("VPCVPNGateway")
$iconRow("VPCVirtualprivatecloudVPC")
$iconRow("VerifiedAccess")
$iconRow("VirtualPrivateCloud")
endlegend

@enduml
```

## QuantumTechnologies

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/QuantumTechnologies/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Braket")
$iconRow("BraketChandelier")
$iconRow("BraketChip")
$iconRow("BraketEmbeddedSimulator")
$iconRow("BraketManagedSimulator")
$iconRow("BraketNoiseSimulator")
$iconRow("BraketQPU")
$iconRow("BraketSimulator")
$iconRow("BraketSimulator1")
$iconRow("BraketSimulator2")
$iconRow("BraketSimulator3")
$iconRow("BraketSimulator4")
$iconRow("BraketStateVector")
$iconRow("BraketTensorNetwork")
$iconRow("QuantumTechnologies")
endlegend

@enduml
```

## Satellite

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Satellite/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("GroundStation")
$iconRow("Satellite")
endlegend

@enduml
```

## SecurityIdentityCompliance

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/SecurityIdentityCompliance/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Artifact")
$iconRow("AuditManager")
$iconRow("CertificateManager")
$iconRow("CertificateManagerCertificateAuthority")
$iconRow("CloudDirectory")
$iconRow("CloudHSM")
$iconRow("Cognito")
$iconRow("Detective")
$iconRow("DirectoryService")
$iconRow("DirectoryServiceADConnector")
$iconRow("DirectoryServiceAWSManagedMicrosoftAD")
$iconRow("DirectoryServiceSimpleAD")
$iconRow("FirewallManager")
$iconRow("GuardDuty")
$iconRow("IAMIdentityCenter")
$iconRow("IdentityAccessManagementAWSSTS")
$iconRow("IdentityAccessManagementAWSSTSAlternate")
$iconRow("IdentityAccessManagementAddon")
$iconRow("IdentityAccessManagementDataEncryptionKey")
$iconRow("IdentityAccessManagementEncryptedData")
$iconRow("IdentityAccessManagementIAMAccessAnalyzer")
$iconRow("IdentityAccessManagementIAMRolesAnywhere")
$iconRow("IdentityAccessManagementLongTermSecurityCredential")
$iconRow("IdentityAccessManagementMFAToken")
$iconRow("IdentityAccessManagementPermissions")
$iconRow("IdentityAccessManagementRole")
$iconRow("IdentityAccessManagementTemporarySecurityCredential")
$iconRow("IdentityandAccessManagement")
$iconRow("Inspector")
$iconRow("InspectorAgent")
$iconRow("KeyManagementService")
$iconRow("KeyManagementServiceExternalKeyStore")
$iconRow("Macie")
$iconRow("NetworkFirewall")
$iconRow("NetworkFirewallEndpoints")
$iconRow("PaymentCryptography")
$iconRow("PrivateCertificateAuthority")
$iconRow("ResourceAccessManager")
$iconRow("SecretsManager")
$iconRow("SecurityAgent")
$iconRow("SecurityHub")
$iconRow("SecurityHubFinding")
$iconRow("SecurityIdentityCompliance")
$iconRow("SecurityIncidentResponse")
$iconRow("SecurityLake")
$iconRow("Shield")
$iconRow("ShieldAWSShieldAdvanced")
$iconRow("Signer")
$iconRow("VerifiedPermissions")
$iconRow("WAF")
$iconRow("WAFBadBot")
$iconRow("WAFBot")
$iconRow("WAFBotControl")
$iconRow("WAFFilteringRule")
$iconRow("WAFLabels")
$iconRow("WAFManagedRule")
$iconRow("WAFRule")
endlegend

@enduml
```

## Serverless

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Serverless/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Serverless")
endlegend

@enduml
```

## Storage

```plantuml
@startuml
!define awslib https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist
!include awslib/AWSCommon.puml
!include awslib/Storage/all.puml

!procedure $iconRow($name)
| %call_user_func("$" + $name + "IMG") | $name | $%string($name)IMG&#40;&#41; |
!endprocedure

legend
| <b>Icon</b> | <b>Name</b> | <b>Syntax</b> |
$iconRow("Backup")
$iconRow("BackupAWSBackupforAWSCloudFormation")
$iconRow("BackupAWSBackupsupportforAmazonFSxforNetAppONTAP")
$iconRow("BackupAWSBackupsupportforAmazonS3")
$iconRow("BackupAWSBackupsupportforVMwareWorkloads")
$iconRow("BackupAuditManager")
$iconRow("BackupBackupPlan")
$iconRow("BackupBackupRestore")
$iconRow("BackupBackupVault")
$iconRow("BackupComplianceReporting")
$iconRow("BackupCompute")
$iconRow("BackupDatabase")
$iconRow("BackupGateway")
$iconRow("BackupLegalHold")
$iconRow("BackupRecoveryPointObjective")
$iconRow("BackupRecoveryTimeObjective")
$iconRow("BackupStorage")
$iconRow("BackupVaultLock")
$iconRow("BackupVirtualMachine")
$iconRow("BackupVirtualMachineMonitor")
$iconRow("EFS")
$iconRow("ElasticBlockStore")
$iconRow("ElasticBlockStoreAmazonDataLifecycleManager")
$iconRow("ElasticBlockStoreMultipleVolumes")
$iconRow("ElasticBlockStoreSnapshot")
$iconRow("ElasticBlockStoreVolume")
$iconRow("ElasticBlockStoreVolumegp3")
$iconRow("ElasticDisasterRecovery")
$iconRow("ElasticFileSystemElasticThroughput")
$iconRow("ElasticFileSystemFileSystem")
$iconRow("ElasticFileSystemIntelligentTiering")
$iconRow("ElasticFileSystemOneZone")
$iconRow("ElasticFileSystemOneZoneInfrequentAccess")
$iconRow("ElasticFileSystemStandard")
$iconRow("ElasticFileSystemStandardInfrequentAccess")
$iconRow("FSx")
$iconRow("FSxforLustre")
$iconRow("FSxforNetAppONTAP")
$iconRow("FSxforOpenZFS")
$iconRow("FSxforWFS")
$iconRow("FileCache")
$iconRow("FileCacheHybridNFSlinkeddatasets")
$iconRow("FileCacheOnpremisesNFSlinkeddatasets")
$iconRow("FileCacheS3linkeddatasets")
$iconRow("S3onOutposts")
$iconRow("SimpleStorageService")
$iconRow("SimpleStorageServiceBucket")
$iconRow("SimpleStorageServiceBucketWithObjects")
$iconRow("SimpleStorageServiceDirectoryBucket")
$iconRow("SimpleStorageServiceGeneralAccessPoints")
$iconRow("SimpleStorageServiceGlacier")
$iconRow("SimpleStorageServiceGlacierArchive")
$iconRow("SimpleStorageServiceGlacierVault")
$iconRow("SimpleStorageServiceObject")
$iconRow("SimpleStorageServiceS3BatchOperations")
$iconRow("SimpleStorageServiceS3ExpressOneZone")
$iconRow("SimpleStorageServiceS3GlacierDeepArchive")
$iconRow("SimpleStorageServiceS3GlacierFlexibleRetrieval")
$iconRow("SimpleStorageServiceS3GlacierInstantRetrieval")
$iconRow("SimpleStorageServiceS3IntelligentTiering")
$iconRow("SimpleStorageServiceS3MultiRegionAccessPoints")
$iconRow("SimpleStorageServiceS3ObjectLambda")
$iconRow("SimpleStorageServiceS3ObjectLambdaAccessPoints")
$iconRow("SimpleStorageServiceS3ObjectLock")
$iconRow("SimpleStorageServiceS3OnOutposts")
$iconRow("SimpleStorageServiceS3OneZoneIA")
$iconRow("SimpleStorageServiceS3Replication")
$iconRow("SimpleStorageServiceS3ReplicationTimeControl")
$iconRow("SimpleStorageServiceS3Select")
$iconRow("SimpleStorageServiceS3Standard")
$iconRow("SimpleStorageServiceS3StandardIA")
$iconRow("SimpleStorageServiceS3StorageLens")
$iconRow("SimpleStorageServiceS3Tables")
$iconRow("SimpleStorageServiceS3Vectors")
$iconRow("SimpleStorageServiceVPCAccessPoints")
$iconRow("Snowball")
$iconRow("SnowballEdge")
$iconRow("SnowballSnowballImportExport")
$iconRow("Storage")
$iconRow("StorageGateway")
$iconRow("StorageGatewayAmazonFSxFileGateway")
$iconRow("StorageGatewayAmazonS3FileGateway")
$iconRow("StorageGatewayCachedVolume")
$iconRow("StorageGatewayFileGateway")
$iconRow("StorageGatewayNoncachedVolume")
$iconRow("StorageGatewayTapeGateway")
$iconRow("StorageGatewayVirtualTapeLibrary")
$iconRow("StorageGatewayVolumeGateway")
endlegend

@enduml
```

