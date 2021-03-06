module System.OpenCL.Wrappers.CommandQueue 
    (clCreateCommandQueue
    ,clRetainCommandQueue
    ,clReleaseCommandQueue
    ,clGetCommandQueueInfo
    ,clSetCommandQueueProperty)
where

import Data.Bits
import Data.List
import System.OpenCL.Wrappers.Types
import System.OpenCL.Wrappers.Utils
import System.OpenCL.Wrappers.Raw
import Foreign.Marshal.Alloc(alloca)
import Foreign.Storable(peek)


clCreateCommandQueue :: Context -> DeviceID -> [CommandQueueProperties] -> IO (Either ErrorCode CommandQueue)
clCreateCommandQueue ctx devid props =
    wrapErrorEither $ raw_clCreateCommandQueue ctx devid properties
    where properties = foldl' (.|.) 0 [ prop | CommandQueueProperties prop <- props ]

clRetainCommandQueue :: CommandQueue -> IO (Maybe ErrorCode)
clRetainCommandQueue queue = wrapError (raw_clRetainCommandQueue queue)

clReleaseCommandQueue :: CommandQueue -> IO (Maybe ErrorCode)
clReleaseCommandQueue queue = wrapError (raw_clReleaseCommandQueue queue)

clGetCommandQueueInfo :: CommandQueue -> CommandQueueInfo -> IO (Either ErrorCode CLCommandQueueInfoRetval)
clGetCommandQueueInfo ctx (CommandQueueInfo param_name) = wrapGetInfo (raw_clGetCommandQueueInfo ctx param_name) >>=
    either (return.Left) (\(x,_) -> fmap Right $ let c = (CommandQueueInfo param_name) in case () of 
        ()
            | c == clQueueContext        -> peekOneInfo CommandQueueInfoRetvalContext x
            | c == clQueueDevice         -> peekOneInfo CommandQueueInfoRetvalDeviceID x
            | c == clQueueReferenceCount -> peekOneInfo CommandQueueInfoRetvalCLuint x
            | c == clQueueProperties     -> peekOneInfo CommandQueueInfoRetvalCommandQueueProperties x
            | otherwise                  -> undefined)

{-# DEPRECATED clSetCommandQueueProperty "Deprecated in C api" #-}
clSetCommandQueueProperty :: CommandQueue -> CommandQueueProperties -> Bool -> IO (Either ErrorCode CommandQueueProperties)
clSetCommandQueueProperty queue (CommandQueueProperties properties) enable = alloca $ \old_properties ->
    wrapError (raw_clSetCommandQueueProperty queue properties (if enable then clTrue else clFalse) old_properties) >>=
        maybe (fmap (Right . CommandQueueProperties) $ peek old_properties) (return . Left)
