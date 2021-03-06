module System.OpenCL.Wrappers.Kernel 
    (clCreateKernel
    ,clCreateKernelsInProgram
    ,clRetainKernel
    ,clReleaseKernel
    ,clGetKernelInfo
    ,clSetKernelArg
    ,clGetKernelWorkGroupInfo
    ,clEnqueueNDRangeKernel
    ,clEnqueueTask
    ,clEnqueueNativeKernel)
where

import System.OpenCL.Wrappers.Types
import System.OpenCL.Wrappers.Utils
import System.OpenCL.Wrappers.Raw
import Foreign
import Foreign.C
import Control.Applicative
import Data.Maybe


clCreateKernel :: Program -> String -> IO (Either ErrorCode Kernel)
clCreateKernel program init_name = withCString init_name (\x -> wrapErrorEither $ raw_clCreateKernel program x)

clCreateKernelsInProgram :: Program -> CLuint -> IO (Either ErrorCode [Kernel])
clCreateKernelsInProgram program num_kernels = allocaArray (fromIntegral num_kernels) $ \kernels -> alloca $ \num_kernels_ret -> do
    err <- wrapError $ raw_clCreateKernelsInProgram program num_kernels kernels num_kernels_ret
    if err== Nothing
        then do 
            nkr <- peek num_kernels_ret
            Right <$> peekArray (fromIntegral nkr) kernels
        else
            return $ Left . fromJust $ err

clRetainKernel :: Kernel -> IO (Maybe ErrorCode)
clRetainKernel kernel = wrapError $ raw_clRetainKernel kernel

clReleaseKernel :: Kernel -> IO (Maybe ErrorCode)
clReleaseKernel kernel = wrapError $ raw_clRetainKernel kernel

clSetKernelArg :: Kernel -> CLuint -> CLsizei -> Ptr () -> IO (Maybe ErrorCode)
clSetKernelArg kernel arg_index arg_size arg_value = 
    wrapError $ raw_clSetKernelArg kernel arg_index arg_size arg_value

clGetKernelInfo :: Kernel -> KernelInfo -> IO (Either ErrorCode CLKernelInfoRetval)
clGetKernelInfo kernel (KernelInfo param_name) = (wrapGetInfo $ raw_clGetKernelInfo kernel param_name) >>= 
    either (return.Left) (\(x,_) -> fmap Right $ let c = (KernelInfo param_name) in case () of 
        ()
            | c == clKernelFunctionName   -> peekStringInfo KernelInfoRetvalString x
            | c == clKernelNumArgs        -> peekOneInfo KernelInfoRetvalCLuint x
            | c == clKernelReferenceCount -> peekOneInfo KernelInfoRetvalCLuint x
            | c == clKernelContext        -> peekOneInfo KernelInfoRetvalContext x
            | c == clKernelProgram        -> peekOneInfo KernelInfoRetvalProgram x
            | otherwise                   -> undefined)

clGetKernelWorkGroupInfo :: Kernel -> DeviceID -> KernelWorkGroupInfo -> IO (Either ErrorCode CLKernelWorkGroupInfoRetval)
clGetKernelWorkGroupInfo kernel device (KernelWorkGroupInfo param_name) = (wrapGetInfo $ raw_clGetKernelWorkGroupInfo kernel device param_name) >>=
    either (return.Left) (\(x,size) -> fmap Right $ let c = (KernelWorkGroupInfo param_name) in case () of 
        ()
            | c == clKernelWorkGroupSize        -> peekOneInfo KernelWorkGroupInfoRetvalCLsizei x
            | c == clKernelCompileWorkGroupSize -> peekManyInfo KernelWorkGroupInfoRetvalCLsizeiList x size
            | c == clKernelLocalMemSize         -> peekOneInfo KernelWorkGroupInfoRetvalCLulong x
            | otherwise                         -> undefined)

clEnqueueNDRangeKernel :: CommandQueue -> Kernel -> [CLsizei] -> [CLsizei] -> [Event] -> IO (Either ErrorCode Event) 
clEnqueueNDRangeKernel queue kernel global_work_sizeL local_work_sizeL event_wait_listL = 
    withArray global_work_sizeL $ \global_work_size ->
    withArrayNull local_work_sizeL $ \local_work_size ->
    withArrayNull event_wait_listL $ \event_wait_list ->
    alloca $ \event -> do
        err <- wrapError $ raw_clEnqueueNDRangeKernel queue kernel (fromIntegral work_dim) nullPtr global_work_size local_work_size (fromIntegral num_events_in_wait_list) event_wait_list event
        if err == Nothing
            then Right <$> peek event
            else return $ Left . fromJust $ err
    where work_dim = length global_work_sizeL
          num_events_in_wait_list = length event_wait_listL
        
clEnqueueTask :: CommandQueue -> Kernel -> [Event] -> IO (Either ErrorCode Event)
clEnqueueTask queue kernel event_wait_listL = 
    allocaArray num_events_in_wait_list $ \event_wait_list ->
    alloca $ \event -> do
        pokeArray event_wait_list event_wait_listL
        err <- wrapError $ raw_clEnqueueTask queue kernel (fromIntegral num_events_in_wait_list) event_wait_list event 
        if err == Nothing
            then Right <$> peek event
            else return $ Left . fromJust $ err
    where num_events_in_wait_list = length event_wait_listL

clEnqueueNativeKernel :: NativeKernelCallback -> Ptr () -> CLsizei -> [Mem] -> [Ptr ()] -> [Event] -> IO (Either ErrorCode Event)
clEnqueueNativeKernel user_funcF args cb_args mem_listL args_mem_locL event_wait_listL = 
    allocaArray num_events_in_wait_list $ \event_wait_list ->
    allocaArray num_mem_objects $ \mem_list ->
    allocaArray (length args_mem_locL) $ \args_mem_loc -> 
    alloca $ \event -> do
        user_func <- wrapNativeKernelCallback user_funcF
        pokeArray event_wait_list event_wait_listL
        pokeArray mem_list mem_listL
        pokeArray args_mem_loc args_mem_locL
        err <- wrapError $ raw_clEnqueueNativeKernel user_func args cb_args (fromIntegral num_mem_objects) mem_list args_mem_loc (fromIntegral num_events_in_wait_list) event_wait_list event
        if err == Nothing
            then Right <$> peek event
            else return $ Left . fromJust $ err
    where num_events_in_wait_list = length event_wait_listL
          num_mem_objects = length mem_listL
