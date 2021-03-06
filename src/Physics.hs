module Physics where
import QuadTree

thetaThreshold :: Double
thetaThreshold = 1

g :: Double
g = 50

density :: Double
density = 1/10 -- Object of mass 10 is radius 100, in mass / radius

combineBodies :: Body -> Body -> Body
combineBodies b1 b2 = b1 {mass = mass b1 + mass b2, xVel = xVel b1 + xVel b2, yVel = yVel b1 + yVel b2}

calcCOM :: QuadTree -> QuadTree
calcCOM (QuadNode Nothing qi) = QuadNode Nothing qi
calcCOM (QuadNode (Just b) qi) = QuadNode (Just b) (qi {com = CenterMass (mass b) (xCord b) (yCord b)})
calcCOM qt@(QuadTree _ _ _ _ qi) = QuadTree nw' ne' sw' se' (qi {com = CenterMass totMass newX newY})
    where qs@[nw', ne', sw', se'] = mapQuads calcCOM qt
          totMass = foldr (\q tm -> tm + getCOMM q) 0 qs 
          newX = foldr (\q wx -> wx + getCOMM q * getCOMX q) 0 qs / totMass
          newY = foldr (\q wy -> wy + getCOMM q * getCOMY q) 0 qs / totMass
                      
approximateForce :: QuadTree -> Body -> Double -> Body -- Run Barnes Hut
approximateForce (QuadNode Nothing _) b _ = b -- nothing to compute
approximateForce (QuadNode (Just b1) _) b dt = if b == b1 then b else updateVelocity b b1 dt
approximateForce qt@(QuadTree _ _ _ _ qi) b dt
  | theta < thetaThreshold  = updateVelocity b referenceMass dt-- Treat this quadrant as a single mass
  | otherwise = foldQuads (\qt' b' -> approximateForce qt' b' dt) b qt
  where (xDiff, yDiff) = (xCord b - getCOMX qt, yCord b - getCOMY qt)
        distance = xDiff * xDiff + yDiff * yDiff
        theta = (xr qi - xl qi) / sqrt distance
        referenceMass = Body (getCOMM qt) (getCOMX qt) (getCOMY qt) 0 0 0 -- Consider the COM a body for calculation

doTimeStep :: Double -> Body -> Body
doTimeStep timeStep b = b {xCord = xCord b + xVel b * timeStep, yCord = yCord b + yVel b * timeStep}

updateVelocity :: Body -> Body -> Double -> Body
updateVelocity bodyToUpdate otherBody dt
  | bodyToUpdate == otherBody = bodyToUpdate
  | otherwise = bodyToUpdate {xVel = xVel bodyToUpdate - xVelChange * dt, yVel = yVel bodyToUpdate - yVelChange * dt}
  where (xDiff, yDiff) = (xCord bodyToUpdate - xCord otherBody, yCord bodyToUpdate - yCord otherBody)
        distance = xDiff * xDiff + yDiff * yDiff
        angleToBody = atan2 yDiff xDiff
        xVelChange = g * cos angleToBody * (mass otherBody / distance)
        yVelChange = g * sin angleToBody * (mass otherBody / distance)

circularVelocity :: Double -> Double -> Double
circularVelocity massSun radius' = sqrt (g * massSun / radius') 

generateOrbiter :: Body -> Double -> Double -> Body
generateOrbiter sun radius' mass' = Body mass' (xCord sun + radius') (yCord sun) (xVel sun) (yVel sun + velocity) (mass' / density)-- Start at same y level
  where velocity = circularVelocity (mass sun) radius'

generateOrbiterAngle :: Body -> Double -> Double -> Double -> Body
generateOrbiterAngle sun radius' mass' angle = Body mass' (xPos) (yPos) (xVel') (yVel') (mass' / density)-- Start at same y level
  where velocity = circularVelocity (mass sun) radius'
        xVel' = xVel sun + velocity * sin (angle + pi / 2 :: Double) 
        yVel' = yVel sun + velocity * cos (angle + pi / 2 :: Double)  
        xPos = xCord sun + (sin angle) * radius'
        yPos = xCord sun + (cos angle) * radius'

