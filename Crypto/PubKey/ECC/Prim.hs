-- | Elliptic Curve Arithmetic.
--
-- /WARNING:/ These functions are vulnerable to timing attacks.
module Crypto.PubKey.ECC.Prim
    ( pointAdd
    , pointDouble
    , pointMul
    ) where

import Data.Maybe
import Crypto.Number.ModArithmetic
import Crypto.Number.F2m
import Crypto.Types.PubKey.ECC

-- | Elliptic Curve point addition.
--
-- /WARNING:/ Vulnerable to timing attacks.
pointAdd :: Curve -> Point -> Point -> Point
pointAdd _ PointO PointO = PointO
pointAdd _ PointO q = q
pointAdd _ p PointO = p
pointAdd c@(CurveFP (CurvePrime pr _)) p@(Point xp yp) q@(Point xq yq)
    | p == Point xq (-yq) = PointO
    | p == q = pointDouble c p
    | otherwise = let s  = divmod (yp - yq) (xp - xq) pr
                      xr = (s ^ (2::Int) - xp - xq) `mod` pr
                      yr = (s * (xp - xr) - yp) `mod` pr
                  in Point xr yr
pointAdd c@(CurveF2m (CurveBinary fx cc)) p@(Point xp yp) q@(Point xq yq)
    | p == Point xq (xq `addF2m` yq) = PointO
    | p == q = pointDouble c p
    | otherwise = fromMaybe PointO $ do
                     s <- divF2m fx (yp `addF2m` yq) (xp `addF2m` xq)
                     let xr = mulF2m fx s s `addF2m` s `addF2m` xp `addF2m` xq `addF2m` a
                         yr = mulF2m fx s (xp `addF2m` xr) `addF2m` xr `addF2m` yp
                     return $ Point xr yr
  where a = ecc_a cc

-- | Elliptic Curve point doubling.
--
-- /WARNING:/ Vulnerable to timing attacks.
pointDouble :: Curve -> Point -> Point
pointDouble _ PointO = PointO
pointDouble (CurveFP (CurvePrime pr cc)) (Point xp yp) =
    let l = divmod (3 * xp ^ (2::Int) + a) (2 * yp) pr
        xr = (l ^ (2::Int) - 2 * xp) `mod` pr
        yr = (l * (xp - xr) - yp) `mod` pr
    in Point xr yr
  where a = ecc_a cc
pointDouble (CurveF2m (CurveBinary fx cc)) (Point xp yp) = fromMaybe PointO $ do
    s <- return . addF2m xp =<< divF2m fx yp xp
    let xr = mulF2m fx s s `addF2m` s `addF2m` a
        yr = mulF2m fx xp xp `addF2m` mulF2m fx xr (s `addF2m` 1)
    return $ Point xr yr
  where a = ecc_a cc

-- | Elliptic curve point multiplication (double and add algorithm).
--
-- /WARNING:/ Vulnerable to timing attacks.
pointMul :: Curve -> Integer -> Point -> Point
pointMul c n p
    | n == 1 = p
    | odd n = pointAdd c p (pointMul c (n - 1) p)
    | otherwise = pointMul c (n `div` 2) (pointDouble c p)

-- | div and mod
divmod :: Integer -> Integer -> Integer -> Integer
divmod y x m = y * fromJust (inverse (x `mod` m) m) `mod` m
