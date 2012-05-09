{-# LANGUAGE PatternGuards #-}
module Options.Applicative.Help where

import Data.Lens.Common
import Data.List
import Data.Maybe
import Options.Applicative
import Options.Applicative.Types
import Options.Applicative.Utils

showOption :: OptName -> String
showOption (OptLong n) = "--" ++ n
showOption (OptShort n) = '-' : [n]

data OptDescStyle = OptDescStyle
  { descSep :: String
  , descHidden :: Bool
  , descSurround :: Bool }

optDesc :: OptDescStyle -> Option r a -> String
optDesc style opt =
  let ns = optionNames $ opt^.optMain
      mv = opt^.optMetaVar
      descs = map showOption (sort ns)
      desc' = intercalate (descSep style) descs <+> mv
      render text
        | not (opt^.optShow) && not (descHidden style)
        = ""
        | null text || not (descSurround style)
        = text
        | isJust (opt^.optDefault)
        = "[" ++ text ++ "]"
        | null (drop 1 descs)
        = text
        | otherwise
        = "(" ++ text ++ ")"
  in render desc'

cmdDesc :: Parser a -> String
cmdDesc = vcat
        . take 1
        . filter (not . null)
        . mapParser desc
  where
    desc opt
      | CmdReader cmds p <- opt^.optMain
      = tabulate [(cmd, d)
                 | cmd <- cmds
                 , d <- maybeToList . fmap infoProgDesc $ p cmd ]
      | otherwise
      = ""

shortDesc :: Parser a -> String
shortDesc = foldr (<+>) "" . mapParser (optDesc style)
  where
    style = OptDescStyle
      { descSep = "|"
      , descHidden = False
      , descSurround = True }

fullDesc :: Parser a -> String
fullDesc = tabulate . catMaybes . mapParser doc
  where
    doc opt
      | null n = Nothing
      | null h = Nothing
      | otherwise = Just (n, h)
      where n = optDesc style opt
            h = opt^.optHelp
    style = OptDescStyle
      { descSep = ","
      , descHidden = True
      , descSurround = False }

parserHelpText :: ParserInfo a -> String
parserHelpText pinfo = unlines
   $ nn [infoHeader pinfo]
  ++ [ "  " ++ line | line <- nn [infoProgDesc pinfo] ]
  ++ [ line | desc <- nn [fullDesc p]
            , line <- ["", "Common options:", desc]
            , infoFullDesc pinfo ]
  ++ [ line | desc <- nn [cmdDesc p]
            , line <- ["", "Available commands:", desc]
            , infoFullDesc pinfo ]
  ++ [ line | footer <- nn [infoFooter pinfo]
            , line <- ["", footer] ]
  where
    nn = filter (not . null)
    p = infoParser pinfo