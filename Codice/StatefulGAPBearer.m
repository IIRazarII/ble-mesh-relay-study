classdef StatefulGAPBearer < ble.internal.linkLayerGAPBearer
    % This class implements the "Stateful Preemption" mechanism.
    % It ensures the scanning process resumes from the interrupted channel
    % and completes the remaining Scan Interval duration.

    properties (Access = protected)
        TRSI = 0                % Remaining Scan Interval time in microseconds
        SavedChannelIndex = -1  % Index of the channel where scanning was interrupted
        
        % Real-time logging variables
        EnableLogging = true;   % Toggle to enable/disable console logging
        PrintInterval = 5e6;    % Print every 5,000,000 microseconds (5 simulated seconds)
    end

    methods
        % Constructor
        function obj = StatefulGAPBearer(notificationFcn, varargin)
            % Call the superclass constructor using the full package path
            obj@ble.internal.linkLayerGAPBearer(notificationFcn, varargin{:});
            
            % Enable preemption to allow advertising to interrupt scanning
            obj.PreemptiveScanning = true; 
        end
        
        % Override the run function to add shared optional logging
        function [nextInvokeTime, txLLPacket] = run(obj, currentTime, rxLLPacket)
            % Execute the original state machine logic
            if nargin == 3
                [nextInvokeTime, txLLPacket] = run@ble.internal.linkLayerGAPBearer(obj, currentTime, rxLLPacket);
            else
                [nextInvokeTime, txLLPacket] = run@ble.internal.linkLayerGAPBearer(obj, currentTime);
            end
            
            % --- REAL-TIME LOGGING (SHARED ACROSS ALL NODES) ---
            % Use a persistent variable so it's shared among all class instances
            persistent globalLastPrintTime;
            
            % Reset the timer if it's a completely new simulation run
            if isempty(globalLastPrintTime) || currentTime < globalLastPrintTime
                globalLastPrintTime = 0;
            end
            
            % Print a message only if logging is enabled and the interval has passed.
            % Since the variable is persistent, only the first node reaching the 
            % time threshold will print, preventing console spam.
            if obj.EnableLogging && (currentTime - globalLastPrintTime >= obj.PrintInterval)
                fprintf('Simulation Time: %.2f seconds\n', currentTime / 1e6);
                
                % Update the shared timer
                globalLastPrintTime = currentTime;
            end
        end
    end

    methods (Access = protected)
        
        % 1. OVERRIDE SCANNING: Save state before interrupting for Advertising
        function scanning(obj, elapsedTime, rxLLPacket)
            % If scanning is interrupted by an incoming packet in the queue
            if (obj.PreemptiveScanning && ~isEmpty(obj.pQueue)) && (obj.LastRunTime < obj.pNextEventTime)
                % Calculate and store the remaining time
                obj.TRSI = obj.pNextEventTime - obj.LastRunTime;
                
                % Store the current advertising channel to resume later
                obj.SavedChannelIndex = obj.pChannelIndex;
            end
            
            % Execute the standard scanning logic
            scanning@ble.internal.linkLayerGAPBearer(obj, elapsedTime, rxLLPacket);
        end

        % 2. OVERRIDE SWITCHTOSCANNING: Restore the interrupted state
        function switchToScanning(obj)
            % Execute standard setup (resets timer and advances channel)
            switchToScanning@ble.internal.linkLayerGAPBearer(obj);
            
            % Apply stateful logic if a previous scan was interrupted
            if obj.TRSI > 0
                % Revert to the channel where scanning was interrupted
                obj.pChannelIndex = obj.SavedChannelIndex;
                
                % Assign the remaining time to the next scanning event
                obj.pNextEventTime = obj.LastRunTime + obj.TRSI;
                
                % Update the PHY receiver request with the restored channel
                obj.RxRequest.ChannelIndex = obj.pChannelIndex;
                
                % Reset state memory for the next full Scan Interval cycle
                obj.TRSI = 0; 
            end
        end
    end
end