module Z3.Monad.Spec
  ( spec )
  where

import Test.Hspec

import qualified Z3.Monad as Z3
import Control.Monad.IO.Class (liftIO)

import Example.Monad.IntList ( mkIntListDatatype )

assertFuncName :: Z3.FuncDecl -> String -> Z3.Z3 ()
assertFuncName f expected = do actual <- Z3.getDeclName f >>= Z3.getSymbolString
                               liftIO $ actual `shouldBe` expected

spec :: Spec
spec = do
  context "IntList example with assertions" $ do
    specify "should run" $ do
      Z3.evalZ3 $ do
        intList <- mkIntListDatatype
        [nilC, consC] <- Z3.getDatatypeSortConstructors intList
        [nilR, consR] <- Z3.getDatatypeSortRecognizers intList
        [[],[hdA, tlA]] <- Z3.getDatatypeSortConstructorAccessors intList

        assertFuncName nilC "nil"
        assertFuncName consC "cons"
        assertFuncName hdA "hd"
        assertFuncName tlA "tl"

        nil <- Z3.mkApp nilC []
        fortyTwo <- Z3.mkInteger 42
        fiftySeven <- Z3.mkInteger 57
        l1 <- Z3.mkApp consC [ fortyTwo, nil]
        l2 <- Z3.mkApp consC [ fiftySeven, nil]

        eightyTwo <- Z3.mkInteger 82
        l3 <- Z3.mkApp consC [ eightyTwo, l1]
        l4 <- Z3.mkApp consC [ eightyTwo, l2]
        
        Z3.push

        Z3.assert =<< Z3.mkEq nil l1
        r <- Z3.check
        liftIO $ r `shouldBe` Z3.Unsat

        Z3.pop 1
        Z3.push


        boolS <- Z3.mkBoolSort

        -- Build the list-equiv function

        listEquivSym <- Z3.mkStringSymbol "list-equiv"

        listEquivF <- Z3.mkRecFuncDecl listEquivSym [intList, intList] boolS
        l1s <- Z3.mkFreshConst "l1a" intList
        l2s <- Z3.mkFreshConst "l2a" intList

        rnil1 <- Z3.mkApp nilR [l1s]
        rnil2 <- Z3.mkApp nilR [l2s]
        nilPred <- Z3.mkAnd [rnil1, rnil2] -- Both lists are nil

        rcons1 <- Z3.mkApp consR [l1s] -- First list is cons
        
        rcons2 <- Z3.mkApp consR [l2s] -- Second list is cons
        
        hd1 <- Z3.mkApp hdA [l1s]
        one <- Z3.mkInteger 1
        hd1' <- Z3.mkAdd [hd1, one]
        hd2 <- Z3.mkApp hdA [l2s]
        hdeq <- Z3.mkEq hd1' hd2  -- First head + 1 = second head
        
        tl1 <- Z3.mkApp tlA [l1s]
        tl2 <- Z3.mkApp tlA [l2s]
        tlequiv <- Z3.mkApp listEquivF [tl1, tl2] -- list-equiv tl1 tl2
        
        consPred <- Z3.mkAnd [rcons1, rcons2, hdeq, tlequiv]

        equivBody <- Z3.mkOr [nilPred, consPred] -- lists are nil or cons and equivalent

        -- Define the body of the function
        Z3.addRecDef listEquivF [l1s, l2s] equivBody

        Z3.push

        let listToAST [] = Z3.mkApp nilC []
            listToAST (n:ns) = do
              ns' <- listToAST ns
              nn <- Z3.mkInteger n
              Z3.mkApp consC [ nn, ns' ]


        let twoListsEquiv l1 l2 = do Z3.push
                                     l1' <- listToAST l1
                                     l2' <- listToAST l2
                                     Z3.mkApp listEquivF [l1', l2'] >>= Z3.mkNot >>= Z3.assert
                                     r <- Z3.check
                                     liftIO $ r `shouldBe` if map (+1) l1 == l2 then Z3.Unsat else Z3.Sat
                                     Z3.pop 1

        twoListsEquiv [] []  -- equiv
        twoListsEquiv [1] [1] -- not equiv
        twoListsEquiv [1] [2] -- equiv
        twoListsEquiv [1] [2,2] -- not equiv
        twoListsEquiv [1,2,3] [2,3,4] -- equiv
        twoListsEquiv [1,2,3,4,5,6] [2,3,4,5,6,6] -- not equiv
        twoListsEquiv [1,2,3,4] [2,3,4] -- not equiv
        twoListsEquiv [1,2,3,4,5,5,6] [2,3,4,5,6,6,7] -- equiv
