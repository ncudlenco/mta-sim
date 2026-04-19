--- ClientMultiModalHandler: Client-side event handlers that forward
--- multi-modal capture commands from the server into the native C++ bindings
--- exposed by mtasa-blue's CMultiModalCapture (via CLuaMultiModalDefs).
---
--- Counterpart of MTAClientMultiModalAdapter. For the capture event, acks the
--- server with success + dimensions once the blocking C++ call returns; for
--- the lifecycle and mapping events the reply is silent (best-effort).

local DEBUG_MULTIMODAL = DEBUG_SCREENSHOTS

--- Available iff mtasa-blue was built with CMultiModalCapture. Server side
--- can check `NATIVE_MULTIMODAL_AVAILABLE` to gate factory selection.
if captureMultiModalFrame then
    NATIVE_MULTIMODAL_AVAILABLE = true
    if DEBUG_MULTIMODAL then
        outputDebugString("[ClientMultiModalHandler] Native multi-modal bindings detected")
    end
else
    NATIVE_MULTIMODAL_AVAILABLE = false
    if DEBUG_MULTIMODAL then
        outputDebugString("[ClientMultiModalHandler] Native multi-modal bindings NOT present — adapter will fail-fast")
    end
end

addEvent("onCaptureMultiModalFrame", true)
addEventHandler("onCaptureMultiModalFrame", root,
    function(tag, rgbPath, segPath, depthPath, saveRgb, saveSeg, saveDepth, jpegQ)
        local ok = false
        local w, h = 0, 0

        if captureMultiModalFrame then
            -- The C++ binding blocks until all artifacts are on disk and the
            -- video encoder has accepted the frame (Stage 9 will relax this).
            ok = captureMultiModalFrame(rgbPath or "", segPath or "", depthPath or "",
                                         saveRgb and true or false,
                                         saveSeg  and true or false,
                                         saveDepth and true or false,
                                         tonumber(jpegQ) or 95) and true or false

            -- Dimensions default to the capture surface size (which matches the
            -- client viewport). `guiGetScreenSize` is a reasonable proxy since
            -- the C++ binding doesn't report them back.
            if ok then
                local sw, sh = guiGetScreenSize()
                w, h = sw or 0, sh or 0
            end
        else
            outputDebugString("[ClientMultiModalHandler] captureMultiModalFrame binding missing", 1)
        end

        if DEBUG_MULTIMODAL then
            outputDebugString(string.format("[ClientMultiModalHandler] tag=%s success=%s dims=%dx%d",
                tostring(tag), tostring(ok), w, h))
        end

        triggerServerEvent("onMultiModalFrameCaptured", localPlayer, tag, ok, w, h)
    end)

addEvent("onStartMultiModalVideo", true)
addEventHandler("onStartMultiModalVideo", root,
    function(modalityId, path, width, height, fps, bitrate)
        if not startVideoRecording then return end
        local ok = startVideoRecording(modalityId, path, width, height, fps, bitrate)
        if DEBUG_MULTIMODAL then
            outputDebugString(string.format("[ClientMultiModalHandler] startVideoRecording modality=%d ok=%s",
                modalityId, tostring(ok)))
        end
    end)

addEvent("onStopMultiModalVideo", true)
addEventHandler("onStopMultiModalVideo", root,
    function(modalityId)
        if not stopVideoRecording then return end
        local ok = stopVideoRecording(modalityId)
        if DEBUG_MULTIMODAL then
            outputDebugString(string.format("[ClientMultiModalHandler] stopVideoRecording modality=%d ok=%s",
                modalityId, tostring(ok)))
        end
    end)

addEvent("onSetMultiModalSegmentation", true)
addEventHandler("onSetMultiModalSegmentation", root,
    function(enabled)
        if not setMultiModalSegmentation then return end
        setMultiModalSegmentation(enabled and true or false)
        if DEBUG_MULTIMODAL then
            outputDebugString("[ClientMultiModalHandler] setMultiModalSegmentation " .. tostring(enabled))
        end
    end)

addEvent("onWriteMultiModalMapping", true)
addEventHandler("onWriteMultiModalMapping", root,
    function(path)
        if not writeMultiModalMapping then return end
        local ok = writeMultiModalMapping(path)
        if DEBUG_MULTIMODAL then
            outputDebugString(string.format("[ClientMultiModalHandler] writeMultiModalMapping %s ok=%s",
                tostring(path), tostring(ok)))
        end
    end)
