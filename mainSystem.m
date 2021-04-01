
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%	Author(s): Yashwanth R - yashwanthr@iisc.ac.in
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
close all;

[version, executable, isloaded] = pyversion;
if ~isloaded
    pyversion /usr/bin/python
    py.print() %weird bug where py isn't loaded in an external script
end

% Params:
N_BS_NODE               = 1;
N_UE                    = 1;
WRITE_PNG_FILES         = 1;           % Enable writing plots to PNG
SIM_MOD                 = 1;
% DEBUG                   = 1;
PLOT                    = 1;

keepTXRX_Running = 0;

if SIM_MOD
    chan_type               = "rayleigh"; % Will use only Rayleigh for simulation
    sim_SNR_db              = 15;
    TX_SCALE                = 1;         % Scale for Tx waveform ([0:1])
    bs_ids                  = ones(1, N_BS_NODE);
    ue_ids                  = ones(1, N_UE);

else 
    %Iris params:
    TX_SCALE                = 1;         % Scale for Tx waveform ([0:1])
    chan_type               = "iris";
    USE_HUB                 = 0;
    TX_FRQ                  = 2.5e9;
    RX_FRQ                  = TX_FRQ;
    TX_GN                   = 42;
    TX_GN_ue                = 42;
    RX_GN                   = 42;
    SMPL_RT                 = 5e6;
    N_FRM                   = 10;
    bs_ids                   = string.empty();
    ue_ids                  = string.empty();
    ue_scheds               = string.empty();
    
    bs_ids = ["RF3E000064", "RF3E000037", "RF3E000012"];
    numBSAnts = 16;

    ue_ids= ["RF3E000044"];
    numUEAnts = 16;

    N_BS_NODE               = length(bs_ids);           % Number of nodes/antennas at the BS
    N_UE                    = length(ue_ids);           % Number of UE nodes

    numAntsPerBSNode = numBSAnts / N_BS_NODE;
    numAntsPerUENode = numUEAnts / N_UE;

end
fprintf("5G Testbed@ IISc: IRIS MIMO Setup\n");
fprintf("Transmission type: %s \n",chan_type);

while (1)
    
    %% Downlink Baseband Signal Generation
    
    % System Parameters
    iris_pre_zeropad = 0;
    iris_post_zeropad = 0;
    
    N = 256;
    CP = N/4;
    
    prmSeq = [zadoffChuSeq(3, N+CP-1); 0];
    
    codeRate = 1/2;
    modOrder = 4;
    
    PILOTS_SYMS_IND = [1;6;11];
    DATA_SYMS_IND = [2;3;4;5;7;8;9;10];

    zeroSubcarriers = [1;2;3;127;128;129;254;255;256];
    nonZeroSubcarriers = setdiff(1:N, zeroSubcarriers);
    numDataCarriers = length(nonZeroSubcarriers);
    
    numBits = (1/codeRate) * (1/log2(modOrder)) * length(DATA_SYMS_IND) * length(nonZeroSubcarriers);    
    numSyms = floor(4096 / (N + CP));

    % Data Generation
    
    dataBits = randi([0, 1], numBits, 1);
    
    % Channel coding
%   
    codedBits = zeros((1/codeRate) * numBits, 1);
    
    for iter_pc = 1: floor(numBits/100)
        codedBits_tmp = nrPolarEncode(dataBits((iter_pc - 1) * 100 + 1: iter_pc * 100, 1), (1/codeRate) * 100);
        codedBits((iter_pc - 1) * 200 + 1: iter_pc * 200, 1) = nrRateMatchPolar(codedBits_tmp, 100, (1/codeRate)*100);
    end
    
    codedBits_tmp = nrPolarEncode(dataBits(iter_pc * 100 + 1: iter_pc * 100 + 76), (1/codeRate) * 76);
    codedBits(iter_pc * 200 + 1: iter_pc * 200 + 152, 1) = nrRateMatchPolar(codedBits_tmp, 76, (1/codeRate)*76);
        
    % QAM
    
    modData = qammod(codedBits, modOrder, 'gray', 'InputType', 'bit', 'UnitAveragePower', 1);
    
    % Framing
        
    tx_data_buff = zeros(N, numSyms - 1);
    
    iter_data_syms = 1;
    iter_pilot_syms = 1;
    for iter_syms = 1: (numSyms - 1)
        if (any(DATA_SYMS_IND == iter_syms))        
            tx_data_buff(nonZeroSubcarriers, iter_syms) = modData((iter_data_syms - 1) * numDataCarriers + 1: iter_data_syms * numDataCarriers, 1);
            iter_data_syms = iter_data_syms + 1;
        else
            tx_data_buff(nonZeroSubcarriers, iter_syms) = 4;
            iter_pilot_syms = iter_pilot_syms + 1;
        end            
    end
    
    % OFDM
    t1 = tx_data_buff;
    tx_data_buff = circshift(tx_data_buff, N/2);
    tx_data_buff = ifft(tx_data_buff, N);
    tx_data_buff = [tx_data_buff(end-CP+1: end, :); tx_data_buff];
    
    tx_data = [zeros(iris_pre_zeropad, 1); prmSeq; tx_data_buff(:); zeros(iris_post_zeropad, 1)];
    
    %% Burn Data onto IRIS BS Nodes
    if (SIM_MOD == 0)
        BS_PARAMS = 0;
        
        
    end    
    %% Retreive Data from IRIS UE Antenna Buffers.
    if (SIM_MOD == 0)
        
        
        
    end           
    %% Downlink Baseband Signal Processing at IRIS UE Nodes

    if (SIM_MOD == 1)
        h = 1; %(1/sqrt(2)) * (randn(1, 1) + 1i * randn(1, 1));
        n = 0; %(1/sqrt(2*10*N)) * (randn(size(tx_data_buff)) + 1i * randn(size(tx_data_buff)));
        rx_data = h .* tx_data + n;    end
    
%     % Primary Sync
    
    rx_prm_corr = abs(xcorr(prmSeq, rx_data));
    [~, max_idx] = max(rx_prm_corr);
    plot(rx_prm_corr);
    max_idx = max_idx - length(tx_data) + 1;
    
    % CFO Estimation and Equalization
    
    rx_data = rx_data(max_idx + length(prmSeq): end);
    
    rx_data_buff = zeros(N, numSyms - 1);
    
    % Framing
    
    for iter_syms = 1: (numSyms - 1)
        rx_data_buff(:, iter_syms) = rx_data((iter_syms - 1) * (N + CP) + CP + 1: iter_syms * (N + CP), 1);
    end
    
    % OFDM Demodulation
    
    rx_data_buff = fft(rx_data_buff, N);
    rx_data_buff = circshift(rx_data_buff, N/2);
    
    % Channel Estimation and Equalization
    
    % Phase Error Estimation and Equalization
    
    % Equalized Data Extraction
    
    data_syms_buff = rx_data_buff(nonZeroSubcarriers, DATA_SYMS_IND);
    data_syms = data_syms_buff(:);
    
    % QAM Demodulation
    
    demodData = qamdemod(data_syms, modOrder, 'gray', 'OutputType', 'approxllr', 'UnitAveragePower', 1);

    % Channel Decoding
    
    decodedBits = zeros(numBits, 1);
    
    for iter_pc = 1: floor(numBits/100)
        decodedBits_tmp = nrRateRecoverPolar(demodData((iter_pc - 1) * 200 + 1: iter_pc * 200, 1), 100, 256);
        decodedBits((iter_pc - 1) * 100 + 1: iter_pc * 100, 1) = nrPolarDecode(decodedBits_tmp, 100, (1/codeRate)*100, 8);
    end
    
    decodedBits_tmp = nrRateRecoverPolar(demodData(iter_pc * 200 + 1: iter_pc * 200 + 152, 1), 76, 256);
    decodedBits(iter_pc * 100 + 1: iter_pc * 100 + 76, 1) = nrPolarDecode(decodedBits_tmp, 76, (1/codeRate)*76, 8);
        
    
    %% Evaluation 
    
    if (sum(bitxor(dataBits, decodedBits)) == 0)
        fprintf("Successful Transmission\n");
    else
        fprintf("Failed Reception\n");
    end
    
    if (keepTXRX_Running == 0)
        break;
    end
end

