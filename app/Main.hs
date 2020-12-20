module Main where
import QuadTree
import Physics
import Visualize
import Debug.Trace
import Control.Parallel.Strategies(parMap, runEval, rdeepseq, rseq, parListChunk, using, parBuffer, Eval)
import Control.Concurrent
import System.Environment (getArgs, getProgName)
import System.Exit
import Data.List((\\))
import Data.List.Split(chunksOf)
import Control.DeepSeq


barnesHutParMap :: QuadTree -> Double -> QuadTree
barnesHutParMap oldTree dt = newTree --traceShow newTree newTree
  where oldbodyList = toList oldTree
        updatedBodyList = parMap rdeepseq (\b -> approximateForce oldTree b dt) oldbodyList
        movedBodyList = map (doTimeStep dt) updatedBodyList--parMap rdeepseq (doTimeStep dt) updatedBodyList
        newTree = calcCOM $ fromList movedBodyList (getInfo oldTree)

barnesHutParBufChunks :: Int -> QuadTree -> Double -> QuadTree
barnesHutParBufChunks cz oldTree dt = newTree --traceShow newTree newTree
  where oldbodyList = toList oldTree
        updatedBodyList = concat (map (\bs -> map (\b -> doTimeStep dt $ approximateForce oldTree b dt) bs) (chunksOf cz oldbodyList) `using` parBuffer 100 rdeepseq)
        -- movedBodyList = map (doTimeStep dt) updatedBodyList --`using` parListChunk nChunks rdeepseq
        newTree = calcCOM $ fromList updatedBodyList (getInfo oldTree)

barnesHutParListChunks :: Int -> QuadTree -> Double -> QuadTree
barnesHutParListChunks cz oldTree dt = newTree
  where oldbodyList = toList (oldTree) 
        newTree = fromList (map (\b -> doTimeStep dt $ approximateForce oldTree b dt) oldbodyList `using` parListChunk cz rdeepseq) (getInfo oldTree)
        -- newTree = calcCOM $ fromList updatedBodyList (getInfo oldTree)

barnesHutParBuffer :: QuadTree -> Double -> QuadTree
barnesHutParBuffer oldTree dt = newTree --traceShow newTree newTree
  where oldbodyList = toList oldTree
        updatedBodyList = map (\b -> approximateForce oldTree b dt) oldbodyList `using` parBuffer 100 rdeepseq
        movedBodyList = map (doTimeStep dt) updatedBodyList --`using` parListChunk nChunks rdeepseq
        newTree = calcCOM (fromList movedBodyList (getInfo oldTree))

barnesHut :: QuadTree -> Double -> QuadTree
barnesHut oldTree dt = newTree --traceShow newTree newTree
  where oldbodyList = toList oldTree
        updatedBodyList = map (\b -> approximateForce oldTree b dt) oldbodyList
        movedBodyList = map (doTimeStep dt) updatedBodyList
        newTree = calcCOM $ fromList movedBodyList (getInfo oldTree)

makeTree :: Int -> QuadTree
makeTree n = calcCOM $ insert b1' $ fromList [(\x -> generateOrbiter b1' (fromIntegral x) 10) (spacing + spacing * i) | i <- [0..(n-2)]] (getInfo empty)
  where spacing = 1000

simpleLoop :: Int -> (QuadTree -> Double -> QuadTree) -> QuadTree -> Double -> QuadTree
simpleLoop n f tree dt
  | n > 0 = simpleLoop (n - 1) f (f (calcCOM tree) dt) dt
  | otherwise = calcCOM $ tree

simpleLoop' :: Int -> QuadTree -> Double -> Eval QuadTree
simpleLoop' n tree dt
  | n <= 0 = return tree
  | otherwise = do let oldBodyList = toList tree
                             -- rdeepseq oldBodyList
                   newBodyList <- parListChunk 24 rdeepseq (map (\b -> doTimeStep dt $ approximateForce tree b dt) oldBodyList)
                   newBodyList' <- rdeepseq newBodyList
                   simpleLoop' (n - 1) (calcCOM $ fromList newBodyList' (getInfo tree)) dt

doUsage :: IO ()
doUsage = do progName <- getProgName
             die $ "usage: " ++ progName ++
                 " [-i <iterations> -n <numBodies> [pm|plc <chunk-size>|pb|pbc <chunk-size>]]"

main :: IO ()
main = do 
    args <- getArgs
    case args of
      [] -> runSimulation smol barnesHut
      ["-i", iters, "-n", numBodies] -> (putStrLn . show) $ simpleLoop (read iters) barnesHut (makeTree $ read numBodies) (0.5)
      ["-i", iters, "-n", numBodies, "pm"] -> (putStrLn . show) $ simpleLoop (read iters) barnesHutParMap (makeTree $ read numBodies) (0.5)
      ["-i", iters, "-n", numBodies, "plc", cz] -> (putStrLn . show) $ calcCOM $ simpleLoop (read iters) (barnesHutParListChunks $ read cz) (makeTree $ read numBodies) (0.5)
      ["-i", iters, "-n", numBodies, "pbc", cz] -> (putStrLn . show) $ simpleLoop (read iters) (barnesHutParBufChunks $ read cz) (makeTree $ read numBodies) (0.5)
      ["-i", iters, "-n", numBodies, "pb"] -> (putStrLn . show) $ simpleLoop (read iters) barnesHutParBuffer (makeTree $ read numBodies) (0.5)
      _ -> doUsage

emptySmol = emptyQTree 0 200 0 200
b1' = Body 500000000 0 0 0 0 1
b2' = Body 10 500 0 0 125 200

b1Orbiters = map (\x -> generateOrbiter b1' x 5) [500,1500..150000] --98500]

-- sunMass :: Double
-- sunMass = 1.98892*(10^30)
-- sun = Body sunMass 0 0 0 0
-- mercury = Body (0.3301*(10^24) :: Double) (-0.387 * au) 0 0 (-47.36)
-- venus = Body (4.8685*(10^24) :: Double) (-0.723 * au) 0 0 (-35.02)
-- earth = Body (5.9742*(10^24) :: Double) (-1 * au) 0 0 (-29.783)
-- mars = Body (0.6417*(10^24) :: Double) (-1.524 * au) 0 0 (-24.07)

empty = emptyQTree (-20000) 20000 (-20000) 20000

smol = calcCOM $ insert b1' $ fromList b1Orbiters (getInfo empty)

-- solarSystem = calcCOM $ insert mars $ insert earth $ insert venus $ insert mercury $ insert sun empty

bodyList = [(Body 5 (x * 15 + 100) (x * 15) 0 0 10) | x <- [0..5]]
bigTree = calcCOM $ insert b1' $ foldl (flip insert) empty bodyList

