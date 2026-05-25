classdef ConfigurableGAPBearer < ble.internal.linkLayerGAPBearer
% This class implements the relaying mechanisms (including Stateful Preemption) described in:
% Belli et al., "Relaying Mechanisms in BLE Mesh Networks: A Method for Improving Latency and Reliability,"
% IEEE Internet of Things Journal, 2025. DOI: 10.1109/JIOT.2025.3550831
%
% It ensures that the scanning process resumes from the interrupted channel
% and completes the remaining scan interval duration. Additionally, it allows 
% dynamic configuration of the T_ChPDU parameter (the random delay between 
% consecutive advertising PDUs) if needed.
%
% RelayStrategy values:
% 0 = Without Preemption (Default BLE Mesh behavior)
% 1 = Stateless Preemption (Aborts scan, resets timer on resume)
% 2 = Stateful Preemption (Saves channel/timer, resumes where interrupted)
%
% Note: This script has only been verified to work with MATLAB R2025b.

    properties
        % Definition of the public property to select the relay strategy.
        % Accepts only values 0, 1, or 2. Default value: 0 (Without Preemption).
        RelayStrategy (1,1) double {mustBeMember(RelayStrategy, [0, 1, 2])} = 0
        
        % Minimum gap for random advertising in milliseconds. Default: 1 ms.
        RandomAdvMinGap (1,1) double {mustBeNonnegative} = 1
        
        % Maximum gap for random advertising in milliseconds. Default: 10 ms.
        RandomAdvMaxGap (1,1) double {mustBeNonnegative} = 10
    end

    properties (Access = protected)
        TRSI = 0                % Remaining Scan Interval time in microseconds
        SavedChannelIndex = -1  % Index of the channel where scanning was interrupted
        SavedChannelCounter = 1 % Index of the channel selection counter
    end

    methods
        % Constructor
        function obj = ConfigurableGAPBearer(notificationFcn, varargin)
            % Call the superclass constructor
            obj@ble.internal.linkLayerGAPBearer(notificationFcn, varargin{:});
            
            % Set the native PreemptiveScanning variable based on the chosen strategy
            % (Evaluated only once during node initialization)
            obj.PreemptiveScanning = (obj.RelayStrategy > 0);
        end
    end

    methods (Access = protected)
        
        % 1. OVERRIDE SCANNING: Save state before interrupting for Advertising
        function scanning(obj, elapsedTime, rxLLPacket)
            % Apply the saving logic ONLY for Stateful Preemption (2)
            if obj.RelayStrategy == 2
                % If scanning is interrupted by an incoming packet in the queue
                if (obj.PreemptiveScanning && ~isEmpty(obj.pQueue)) && (obj.LastRunTime < obj.pNextEventTime)
                    % Calculate and store the remaining time
                    obj.TRSI = obj.pNextEventTime - obj.LastRunTime;
                    
                    % Store the current advertising channel to resume later
                    obj.SavedChannelIndex = obj.pChannelIndex;
                    
                    % Store the channel selection counter
                    obj.SavedChannelCounter = obj.pChannelSelectionCounter;
                end
            end
            
            % Execute the standard scanning logic
            scanning@ble.internal.linkLayerGAPBearer(obj, elapsedTime, rxLLPacket);
        end

        % 2. OVERRIDE SWITCHTOSCANNING: Restore the interrupted state
        function switchToScanning(obj)
            % Execute the standard setup (resets timer and advances channel)
            switchToScanning@ble.internal.linkLayerGAPBearer(obj);
            
            % Apply the restoration ONLY for Stateful Preemption (2)
            if obj.RelayStrategy == 2 && obj.TRSI > 0
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

        % 3. OVERRIDE GETRANDOMADVERTISINGINSTANCES
        % Uses the configurable RandomAdvMinGap and RandomAdvMaxGap properties.
        % Includes a safety fallback to default values if input data is invalid,
        % and boundary checks to prevent randi() crashes during high delays.
        function advInstances = getRandomAdvertisingInstances(obj)
            advInstances = zeros(1,3);
            
            % Fetch user-defined properties
            minGapMs = obj.RandomAdvMinGap;
            maxGapMs = obj.RandomAdvMaxGap;
            
            % Default to [1, 10] ms if values are invalid
            if isempty(minGapMs) || isempty(maxGapMs) || minGapMs <= 0 || minGapMs >= maxGapMs
                minGapMs = 1;
                maxGapMs = 10;
            end
            
            % Convert directly into microsecond boundaries
            minUs = minGapMs * 1000; 
            maxUs = maxGapMs * 1000; 
            
            % First advertising instance
            advInstances(1) = randi([minUs, maxUs]);
            
            % Second advertising instance
            minSecond = advInstances(1) + minUs;
            % Cap the second instance so it always leaves at least 'minUs'
            % space before the 20ms boundary for the third packet
            maxSecond = min(advInstances(1) + maxUs, round(obj.AdvertisingInterval*1e6,3) - minUs);
            
            if maxSecond < minSecond
                maxSecond = minSecond;
            end
            advInstances(2) = randi([minSecond, maxSecond]);
            
            % Third advertising instance
            minThird = advInstances(2) + minUs;
            maxThird = min(advInstances(2) + maxUs, round(obj.AdvertisingInterval*1e6,3));
            
            % Ensure IMAX is not less than IMIN
            if maxThird < minThird
                maxThird = minThird;
            end
            
            advInstances(3) = randi([minThird, maxThird]);
        end
    end
end