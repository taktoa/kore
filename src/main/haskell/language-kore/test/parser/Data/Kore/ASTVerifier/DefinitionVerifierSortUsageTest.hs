module Data.Kore.ASTVerifier.DefinitionVerifierSortUsageTest
    (definitionVerifierSortUsageTests) where

import           Test.Tasty                                          (TestTree,
                                                                      testGroup)

import           Data.Kore.AST.Common
import           Data.Kore.AST.Kore
import           Data.Kore.AST.MetaOrObject
import           Data.Kore.ASTVerifier.DefinitionVerifierTestHelpers
import           Data.Kore.Error
import           Data.Kore.Implicit.ImplicitSorts
import           Data.Kore.KoreHelpers

import qualified Data.List                                           as List
import           Data.Maybe                                          (mapMaybe)

data TestFlag
    = CannotSeeSortVariables
    | CannotSeeSortDeclarations
    deriving Eq

data AdditionalTestConfiguration
    = SkipTest
    | AdditionalSentences [KoreSentence]

data TestConfiguration level = TestConfiguration
    { testConfigurationDescription :: !String
    , testConfigurationAdditionalSentences :: ![KoreSentence]
    , testConfigurationAdditionalSortVariables :: ![SortVariable level]
    , testConfigurationCaseBasedConfiguration
        :: ![([TestFlag], AdditionalTestConfiguration)]
    }

data SuccessConfiguration level
    = SuccessConfiguration (TestConfiguration level)
    | SuccessConfigurationSkipAll
data FailureConfiguration level
    = FailureConfiguration (TestConfiguration level)
    | FailureConfigurationSkipAll

data FlaggedTestData = FlaggedTestData
    { flaggedTestDataFlags    :: ![TestFlag]
    , flaggedTestDataTestData :: !([KoreSentence] -> TestData)
    }

definitionVerifierSortUsageTests :: TestTree
definitionVerifierSortUsageTests =
    testGroup
        "Definition verifier - sort usage - unit tests"
        [ expectSuccess "Simplest definition"
            (simpleDefinitionFromSentences (ModuleName "MODULE") [])
        , expectSuccess "Definition with sort"
            ( simpleDefinitionFromSentences (ModuleName "MODULE")
                [ sortSentenceWithSortParameters
                    (SortName "sFailureDescription") []
                ]
            )
        , expectSuccess "Definition with meta alias"
            ( simpleDefinitionFromSentences (ModuleName "MODULE")
                [ metaAliasSentenceWithSortParameters
                    (AliasName "#a") charListMetaSort []
                ]
            )
        , testsForObjectSort
            (CommonDescription "Referencing simple sort")
            (SuccessConfiguration TestConfiguration
                { testConfigurationDescription = "The sort is declared"
                , testConfigurationAdditionalSentences =
                    [ simpleSortSentence (SortName "s") ]
                , testConfigurationAdditionalSortVariables = []
                , testConfigurationCaseBasedConfiguration =
                    [ ([CannotSeeSortDeclarations], SkipTest) ]
                }
            )
            (FailureConfiguration TestConfiguration
                { testConfigurationDescription = "The sort is not declared"
                , testConfigurationAdditionalSentences = []
                , testConfigurationAdditionalSortVariables = []
                , testConfigurationCaseBasedConfiguration =
                    [
                        ( [ CannotSeeSortDeclarations ]
                        , AdditionalSentences
                            [ simpleSortSentence (SortName "s") ]
                        )
                    ]
                }
            )
            (ExpectedErrorMessage "Sort 's' not declared.")
            (ErrorStack ["sort 's' (<test data>)", "(<test data>)"])
            (TestedSort (simpleSort (SortName "s")))
            (NamePrefix "#internal")
        , testsForObjectSort
            (CommonDescription "Referencing sort variable")
            (SuccessConfiguration TestConfiguration
                { testConfigurationDescription = "The variable is declared"
                , testConfigurationAdditionalSentences = []
                , testConfigurationAdditionalSortVariables =
                    [ sortVariable Object (SortVariableName "s") ]
                , testConfigurationCaseBasedConfiguration =
                    [
                        ( [CannotSeeSortDeclarations, CannotSeeSortVariables]
                        , SkipTest
                        )
                    ]
                }
            )
            (FailureConfiguration TestConfiguration
                { testConfigurationDescription = "The variable is not declared"
                , testConfigurationAdditionalSentences = []
                , testConfigurationAdditionalSortVariables = []
                , testConfigurationCaseBasedConfiguration = []
                }
            )
            (ExpectedErrorMessage "Sort variable 's' not declared.")
            (ErrorStack ["(<test data>)"])
            (TestedSort (objectVariableSort (SortVariableName "s")))
            (NamePrefix "internal")
        , let
            referencingSortVariableTestConfiguration = TestConfiguration
                { testConfigurationDescription = "Referencing sort variable"
                , testConfigurationAdditionalSentences =
                    [ simpleSortSentence additionalSortName ]
                , testConfigurationAdditionalSortVariables =
                    [ sortVariable Object (SortVariableName "s") ]
                , testConfigurationCaseBasedConfiguration =
                    [
                        ( [CannotSeeSortDeclarations, CannotSeeSortVariables]
                        , SkipTest
                        )
                    ]
                }
          in
            expectSuccessFlaggedTests
                (SuccessConfiguration referencingSortVariableTestConfiguration)
                (flaggedObjectTestsForSort
                    referencingSortVariableTestConfiguration
                    (TestedSort (objectVariableSort (SortVariableName "s")))
                    (SortActualThatIsDeclared
                        (simpleSortActual additionalSortName))
                    (NamePrefix "internal")
                )
        , successTestsForMetaSort
            (CommonDescription "Referencing simple sort")
            (SuccessConfiguration TestConfiguration
                { testConfigurationDescription = "The sort is declared"
                , testConfigurationAdditionalSentences = []
                , testConfigurationAdditionalSortVariables = []
                , testConfigurationCaseBasedConfiguration = []
                }
            )
            (TestedSort (simpleSort (SortName "#CharList")))
            (SortActualThatIsDeclared (simpleSortActual (SortName "#Char")))
            (NamePrefix "#internal")
        , failureTestsForMetaSort
            (CommonDescription "Referencing simple sort")
            (FailureConfiguration TestConfiguration
                { testConfigurationDescription = "The sort is not declared"
                , testConfigurationAdditionalSentences = []
                , testConfigurationAdditionalSortVariables = []
                , testConfigurationCaseBasedConfiguration = []
                }
            )
            (ExpectedErrorMessage "Sort '#s' not declared.")
            (ErrorStack ["sort '#s' (<test data>)", "(<test data>)"])
            (TestedSort (simpleSort (SortName "#s")))
            (SortActualThatIsDeclared (simpleSortActual (SortName "#Char")))
            (NamePrefix "#internal")
        , successTestsForMetaSort
            (CommonDescription "Referencing simple sort")
            (SuccessConfiguration TestConfiguration
                { testConfigurationDescription = "The sort is declared"
                , testConfigurationAdditionalSentences = []
                , testConfigurationAdditionalSortVariables =
                    [ sortVariable Meta (SortVariableName "#s") ]
                , testConfigurationCaseBasedConfiguration =
                    [([CannotSeeSortVariables], SkipTest)]
                }
            )
            (TestedSort (sortVariableSort (SortVariableName "#s")))
            (SortActualThatIsDeclared (simpleSortActual (SortName "#Char")))
            (NamePrefix "#internal")
        , testsForObjectSort
            (CommonDescription "Referencing parametrized sort")
            (SuccessConfiguration TestConfiguration
                { testConfigurationDescription = "Correct sort count"
                , testConfigurationAdditionalSentences =
                    [ simpleSortSentence additionalSortName
                    , asSentence
                        (SentenceSort
                            { sentenceSortName = testId "UnarySort"
                            , sentenceSortParameters = [ SortVariable (testId "svn") ]
                            , sentenceSortAttributes =
                                Attributes []
                            }
                        :: KoreSentenceSort)
                    ]
                , testConfigurationAdditionalSortVariables = []
                , testConfigurationCaseBasedConfiguration =
                    [ ([CannotSeeSortDeclarations], SkipTest) ]
                }
            )
            FailureConfigurationSkipAll
            (ExpectedErrorMessage "None")
            (ErrorStack [])
            (TestedSort
                (SortActualSort SortActual
                    { sortActualName = testId "UnarySort"
                    , sortActualSorts = [ simpleSort additionalSortName ]
                    }
                )
            )
            (NamePrefix "internal")
        , testsForObjectSort
            (CommonDescription "Referencing parametrized sort")
            SuccessConfigurationSkipAll
            (FailureConfiguration TestConfiguration
                { testConfigurationDescription = "Wrong sort count"
                , testConfigurationAdditionalSentences =
                    [ simpleSortSentence additionalSortName
                    , asSentence
                        (SentenceSort
                            { sentenceSortName = testId "UnarySort"
                            , sentenceSortParameters = [ SortVariable (testId "svn") ]
                            , sentenceSortAttributes =
                                Attributes []
                            }
                        :: KoreSentenceSort)
                    ]
                , testConfigurationAdditionalSortVariables = []
                , testConfigurationCaseBasedConfiguration =
                    [ ([CannotSeeSortDeclarations], SkipTest) ]
                }
            )
            (ExpectedErrorMessage "Expected 1 sort arguments, but got 2.")
            (ErrorStack ["sort 'UnarySort' (<test data>)"])
            (TestedSort
                (SortActualSort SortActual
                    { sortActualName = testId "UnarySort"
                    , sortActualSorts =
                        [ simpleSort additionalSortName
                        , simpleSort additionalSortName]
                    }
                )
            )
            (NamePrefix "internal")
         ]
  where
    additionalSortName = SortName "additionalSort1"

newtype CommonDescription = CommonDescription String

testsForObjectSort
    :: CommonDescription
    -> SuccessConfiguration Object
    -> FailureConfiguration Object
    -> ExpectedErrorMessage
    -> ErrorStack
    -> TestedSort Object
    -> NamePrefix
    -> TestTree
testsForObjectSort
    (CommonDescription commonDescription)
    successConfiguration
    failureConfiguration
    expectedErrorMessage
    errorStack
    sort
    namePrefix@(NamePrefix rawNamePrefix)
  =
    testGroup
        commonDescription
        (
            (case successConfiguration of
                SuccessConfigurationSkipAll -> []
                SuccessConfiguration testConfiguration ->
                    let
                        successTestConfiguration =
                            addAdditionalSortSentence testConfiguration
                    in
                        [ expectSuccessFlaggedTests
                            (SuccessConfiguration successTestConfiguration)
                            (testConfigurationToFlaggedTests
                                successTestConfiguration)
                        ]
            )
            ++
            (case failureConfiguration of
                FailureConfigurationSkipAll -> []
                FailureConfiguration testConfiguration ->
                    let
                        failureTestConfiguration =
                            addAdditionalSortSentence testConfiguration
                    in
                        [ expectFailureWithErrorFlaggedTests
                            (FailureConfiguration failureTestConfiguration)
                            expectedErrorMessage
                            errorStack
                            (testConfigurationToFlaggedTests
                                failureTestConfiguration)
                        ]
            )
        )
  where
    testConfigurationToFlaggedTests configuration =
        flaggedObjectTestsForSort
            configuration
            sort
            (SortActualThatIsDeclared additionalSortActual)
            namePrefix
    additionalSortActualName = SortName (rawNamePrefix ++ "_declaredSort")
    additionalSortActual = simpleSortActual additionalSortActualName
    additionalSortSentence = simpleSortSentence additionalSortActualName
    addAdditionalSortSentence =
        addSentenceToTestConfiguration additionalSortSentence

addSentenceToTestConfiguration
    :: KoreSentence -> TestConfiguration level -> TestConfiguration level
addSentenceToTestConfiguration
    sentence
    configuration@TestConfiguration
        { testConfigurationAdditionalSentences = existingSentences }
  =
    configuration
        { testConfigurationAdditionalSentences = sentence : existingSentences }

successTestsForMetaSort
    :: CommonDescription
    -> SuccessConfiguration Meta
    -> TestedSort Meta
    -> SortActualThatIsDeclared Meta
    -> NamePrefix
    -> TestTree
successTestsForMetaSort
    (CommonDescription commonDescription)
    successConfiguration@(SuccessConfiguration testConfiguration)
    sort
    additionalSortActual
    namePrefix
  =
    testGroup
        commonDescription
        [ expectSuccessFlaggedTests successConfiguration flaggedTests]
  where
    flaggedTests =
        flaggedMetaTestsForSort
            testConfiguration
            sort
            additionalSortActual
            namePrefix


failureTestsForMetaSort
    :: CommonDescription
    -> FailureConfiguration Meta
    -> ExpectedErrorMessage
    -> ErrorStack
    -> TestedSort Meta
    -> SortActualThatIsDeclared Meta
    -> NamePrefix
    -> TestTree
failureTestsForMetaSort
    (CommonDescription commonDescription)
    failureConfiguration@(FailureConfiguration testConfiguration)
    expectedErrorMessage
    errorStack
    sort
    additionalSortActual
    namePrefix
  =
    testGroup
        commonDescription
        [ expectFailureWithErrorFlaggedTests
            failureConfiguration expectedErrorMessage errorStack flaggedTests
        ]
  where
    flaggedTests =
        flaggedMetaTestsForSort
            testConfiguration
            sort
            additionalSortActual
            namePrefix

expectSuccessFlaggedTests
    :: SuccessConfiguration level
    -> [FlaggedTestData]
    -> TestTree
expectSuccessFlaggedTests
    (SuccessConfiguration testConfiguration)
    flaggedTests
  =
    testGroup (testConfigurationDescription testConfiguration)
        (map successTestData
            (applyTestConfiguration testConfiguration flaggedTests)
        )

expectFailureWithErrorFlaggedTests
    :: FailureConfiguration level
    -> ExpectedErrorMessage
    -> ErrorStack
    -> [FlaggedTestData]
    -> TestTree
expectFailureWithErrorFlaggedTests
    (FailureConfiguration testConfiguration)
    errorMessage
    additionalErrorStack
    flaggedTests
  =
    testGroup (testConfigurationDescription testConfiguration)
        (map
            (failureTestData errorMessage additionalErrorStack)
            (applyTestConfiguration testConfiguration flaggedTests)
        )

flaggedObjectTestsForSort
    :: TestConfiguration Object
    -> TestedSort Object
    -> SortActualThatIsDeclared Object
    -> NamePrefix
    -> [FlaggedTestData]
flaggedObjectTestsForSort
    testConfiguration
    sort
    additionalSortActual
    namePrefix
  =
    unfilteredTestExamplesForSort Object
        sort
        additionalSortActual
        sortVariables
        namePrefix
        asSentence
        asSentence
    ++ unfilteredTestExamplesForObjectSort
        sort
        additionalSortActual
        sortVariables
        namePrefix
  where
    sortVariables =
        testConfigurationAdditionalSortVariables testConfiguration

flaggedMetaTestsForSort
    :: TestConfiguration Meta
    -> TestedSort Meta
    -> SortActualThatIsDeclared Meta
    -> NamePrefix
    -> [FlaggedTestData]
flaggedMetaTestsForSort
    testConfiguration
    sort
    additionalSortActual
    namePrefix
  =
    unfilteredTestExamplesForSort Meta
        sort
        additionalSortActual
        (testConfigurationAdditionalSortVariables testConfiguration)
        namePrefix
        asSentence
        asSentence

applyTestConfiguration
    :: TestConfiguration level
    -> [FlaggedTestData]
    -> [TestData]
applyTestConfiguration testConfiguration =
    mapMaybe (applyOneTestConfiguration testConfiguration)

applyOneTestConfiguration
    :: TestConfiguration level
    -> FlaggedTestData
    -> Maybe TestData
applyOneTestConfiguration testConfiguration flaggedTestData =
  case currentConfiguration of
    Nothing -> Just (testDataFunction additionalSentences)
    Just SkipTest -> Nothing
    Just (AdditionalSentences moreSentences) ->
        Just (testDataFunction (additionalSentences ++ moreSentences))
  where
    additionalSentences = testConfigurationAdditionalSentences testConfiguration
    testDataFunction = flaggedTestDataTestData flaggedTestData
    currentConfiguration =
        snd <$>
            List.find
                testHasFlags
                (testConfigurationCaseBasedConfiguration testConfiguration)
    testHasFlags configurationWithFlags =
        any
            (`elem` flaggedTestDataFlags flaggedTestData)
            (fst configurationWithFlags)

newtype TestedSort level = TestedSort (Sort level)
newtype SortActualThatIsDeclared level =
    SortActualThatIsDeclared (SortActual level)

unfilteredTestExamplesForSort
    :: MetaOrObject level
    => level
    -> TestedSort level
    -> SortActualThatIsDeclared level
    -> [SortVariable level]
    -> NamePrefix
    -> (KoreSentenceAlias level -> KoreSentence)
    -> (KoreSentenceSymbol level -> KoreSentence)
    -> [FlaggedTestData]
unfilteredTestExamplesForSort
    x
    (TestedSort sort)
    (SortActualThatIsDeclared additionalSortActual)
    sortVariables
    (NamePrefix identifierPrefix)
    sentenceAliasSentence
    sentenceSymbolSentence
  =
    [ FlaggedTestData
        { flaggedTestDataFlags = []
        , flaggedTestDataTestData = \additionalSentences -> TestData
            { testDataDescription = "Alias definition with result sort"
            , testDataError =
                Error
                    [ "module 'MODULE'"
                    , "alias '" ++ rawAliasName ++ "' declaration (<test data>)"
                    ]
                    defaultErrorMessage
            , testDataDefinition =
                simpleDefinitionFromSentences
                    (ModuleName "MODULE")
                    (sentenceAliasSentence
                        (sentenceAliasWithResultSort
                            aliasName sort sortVariables)
                    : additionalSentences
                    )
            }
        }
    , FlaggedTestData
        { flaggedTestDataFlags = []
        , flaggedTestDataTestData = \additionalSentences -> TestData
            { testDataDescription = "Alias definition with sort argument"
            , testDataError =
                Error
                    [ "module 'MODULE'"
                    , "alias '" ++ rawAliasName ++ "' declaration (<test data>)"
                    ]
                    defaultErrorMessage
            , testDataDefinition =
                simpleDefinitionFromSentences
                    (ModuleName "MODULE")
                    (sentenceAliasSentence
                        (sentenceAliasWithSortArgument
                            aliasName sort additionalSort sortVariables)
                    : additionalSentences
                    )
            }
        }
    , FlaggedTestData
        { flaggedTestDataFlags = []
        , flaggedTestDataTestData = \additionalSentences -> TestData
            { testDataDescription =
                "Definition with axiom and binder of sort"
            , testDataError =
                Error
                    [ "module 'MODULE'"
                    , "axiom declaration"
                    , "\\exists '" ++ rawVariableName ++ "'"
                    ]
                    defaultErrorMessage
            , testDataDefinition =
                simpleDefinitionFromSentences
                    (ModuleName "MODULE")
                    ( axiomSentenceWithSortParameters
                        (simpleExistsUnifiedPattern variableName1 sort)
                        (map asUnified sortVariables)
                    : additionalSentences
                    )
            }
        }
    , FlaggedTestData
        { flaggedTestDataFlags = []
        , flaggedTestDataTestData = \additionalSentences -> TestData
            { testDataDescription =
                "Definition with ML pattern and operand sort"
            , testDataError =
                Error
                    [ "module 'MODULE'"
                    , "axiom declaration"
                    , "\\exists '" ++ rawVariableName ++ "'"
                    ]
                    defaultErrorMessage
            , testDataDefinition =
                simpleDefinitionFromSentences
                    (ModuleName "MODULE")
                    ( axiomSentenceWithSortParameters
                        ( simpleExistsEqualsUnifiedPattern
                            variableName1
                            (OperandSort sort)
                            (ResultSort additionalSort)
                        )
                        (map asUnified sortVariables)
                    : additionalSentences
                    )
            }
        }
    , FlaggedTestData
        { flaggedTestDataFlags = []
        , flaggedTestDataTestData = \additionalSentences -> TestData
            { testDataDescription =
                "Definition with ML pattern and operand sort"
            , testDataError =
                Error
                    [ "module 'MODULE'"
                    , "axiom declaration"
                    , "\\exists '" ++ rawVariableName ++ "'"
                    ]
                    defaultErrorMessage
            , testDataDefinition =
                simpleDefinitionFromSentences
                    (ModuleName "MODULE")
                    ( axiomSentenceWithSortParameters
                        ( simpleExistsEqualsUnifiedPattern
                            variableName1
                            (OperandSort additionalSort)
                            (ResultSort sort)
                        )
                        (map asUnified sortVariables)
                    : additionalSentences
                    )
            }
        }
    , FlaggedTestData
        { flaggedTestDataFlags = []
        , flaggedTestDataTestData = \additionalSentences -> TestData
            { testDataDescription = "Definition with application pattern"
            , testDataError =
                Error
                    [ "module 'MODULE'"
                    , "axiom declaration"
                    , "symbol or alias '" ++ rawAliasName ++ "'"
                    ]
                    defaultErrorMessage
            , testDataDefinition =
                simpleDefinitionFromSentences
                    (ModuleName "MODULE")
                    ( axiomSentenceWithSortParameters
                        ( applicationUnifiedPatternWithParams
                            (SymbolName rawAliasName)
                            [sort]
                        )
                        (map asUnified sortVariables)
                    : sentenceSymbolSentence
                        (symbolSentenceWithSortParameters
                            (SymbolName rawAliasName)
                            additionalSortName
                            [sortVariable x sortVariableName1]
                        )
                    : additionalSentences
                    )
            }
        }
    ]
  where
    rawAliasName = identifierPrefix ++ "_alias"
    aliasName = AliasName rawAliasName
    rawVariableName = identifierPrefix ++ "_variable"
    variableName1 = VariableName rawVariableName
    sortVariableName1 = SortVariableName (identifierPrefix ++ "_sortVariable")
    additionalSortRawName = getId (sortActualName additionalSortActual)
    additionalSortName = SortName additionalSortRawName
    additionalSort = SortActualSort additionalSortActual
    defaultErrorMessage = "Replace this with a real error message."

unfilteredTestExamplesForObjectSort
    :: TestedSort Object
    -> SortActualThatIsDeclared Object
    -> [SortVariable Object]
    -> NamePrefix
    -> [FlaggedTestData]
unfilteredTestExamplesForObjectSort
    (TestedSort sort)
    (SortActualThatIsDeclared additionalSortActual)
    sortVariables
    (NamePrefix namePrefix)
  =
    [ FlaggedTestData
        { flaggedTestDataFlags = []
        , flaggedTestDataTestData = \additionalSentences -> TestData
            { testDataDescription = "Definition with complex sort"
            , testDataError =
                Error
                    [ "module 'MODULE'"
                    , "axiom declaration"
                    , "symbol or alias 'a'"
                    , "sort '"
                        ++ differentAdditionalSortRawName
                        ++ "' (<test data>)"
                    ]
                    defaultErrorMessage
            , testDataDefinition =
                simpleDefinitionFromSentences
                    (ModuleName "MODULE")
                    ( axiomSentenceWithSortParameters
                        ( applicationUnifiedPatternWithParams
                            (SymbolName "a")
                            [ SortActualSort SortActual
                                { sortActualName =
                                    testId differentAdditionalSortRawName
                                , sortActualSorts = [sort]
                                }
                            ]
                        )
                        (map asUnified sortVariables)
                    : symbolSentenceWithResultSort
                        (SymbolName "a")
                        (SortActualSort SortActual
                            { sortActualName = testId differentAdditionalSortRawName
                            , sortActualSorts =
                                [ objectVariableSort sortVariableName1 ]
                            }
                        )
                        [sortVariable Object sortVariableName1]
                    : sortSentenceWithSortParameters
                        differentAdditionalSortName
                        [sortVariable Object sortVariableName2]
                    : additionalSentences
                    )
            }
        }
    ]
  where
    sortVariableName1 = SortVariableName (namePrefix ++ "_sortVariable1")
    sortVariableName2 = SortVariableName (namePrefix ++ "_sortVariable2")
    additionalSortRawName = getId (sortActualName additionalSortActual)
    differentAdditionalSortRawName = additionalSortRawName ++ "1"
    differentAdditionalSortName = SortName differentAdditionalSortRawName
    defaultErrorMessage = "Replace this with a real error message."
