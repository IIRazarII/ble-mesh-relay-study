classdef StatefulGAPBearer < ble.internal.linkLayerGAPBearer
% This class implements the Stateful Preemption mechanism described in:
% Belli et al., "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
% IEEE Internet of Things Journal, 2025. DOI: 10.1109/JIOT.2025.3550831
%
% It ensures that the scanning process resumes from the interrupted channel
% and completes the remaining scan interval duration.
%
% Note: This script has only been verified to work with MATLAB R2025b.

    properties (Access = protected)
        TRSI = 0                % Remaining Scan Interval time in microseconds
        SavedChannelIndex = -1  % Index of the channel where scanning was interrupted
        SavedChannelCounter = 1 % Index of the channel selection counter
    end

    methods
        % Constructor
        function obj = StatefulGAPBearer(notificationFcn, varargin)
            % Call the superclass constructor using the full package path
            obj@ble.internal.linkLayerGAPBearer(notificationFcn, varargin{:});
            
            % Enable preemption to allow advertising to interrupt scanning
            obj.PreemptiveScanning = true; 
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
                
                % Store the channel selection counter
                obj.SavedChannelCounter = obj.pChannelSelectionCounter;
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
                
                % Restore the channel selection counter to not skip channels in rotation
                obj.pChannelSelectionCounter = obj.SavedChannelCounter;
                
                % Assign the remaining time to the next scanning event
                obj.pNextEventTime = obj.LastRunTime + obj.TRSI;
                
                % Update the PHY receiver request with the restored channel
                obj.RxRequest.ChannelIndex = obj.pChannelIndex;

                % Synchronize the simulator's event invocation timer with the internal timer
                if ~obj.pSignalAtPHY
                    obj.pNextInvokeTime = obj.pNextEventTime;
                end
                
                % Reset state memory for the next full Scan Interval cycle
                obj.TRSI = 0; 
            end
        end

        % 3. OVERRIDE GETRANDOMADVERTISINGINSTANCES: Custom [1, 10] ms T_ChPDU Interval
        function advInstances = getRandomAdvertisingInstances(obj)
            % Initialize the advertising instances with zeros
            advInstances = zeros(1,3);
            initialGap = 1000; % 1 ms minimum gap in microseconds
            
            % Set to 10000 us to ensure the max gap between intervals reaches 
            % exactly 10 ms
            advGapInUs = 10000; 

            % First advertising instance
            advInstances(1) = randi([initialGap advGapInUs]);
            
            % Second advertising instance
            advInstances(2) = randi([advInstances(1) + obj.USecPerMSec, ...
                advInstances(1) + obj.USecPerMSec + advGapInUs]);
            
            % Third advertising instance
            advInstances(3) = randi([advInstances(2) + obj.USecPerMSec, ...
                min(advInstances(2) + obj.USecPerMSec + advGapInUs, round(obj.AdvertisingInterval*1e6,3))]);
        end
    end
end