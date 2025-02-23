function [OQS] = apply_OWs_C1_v3(QIS)
% OQS = apply_OWs_C1_v3(QIS)
% Accepts a 7D QIS matrix
% Applies Objective-specific weights based on TYP
% Adds Obj[5-8] dimension while eliminating GRP, TYP, and RES dims to produce 5D OQS
% Reduces 4 OBS to 3 OBS 
% NAD from mean of NADBC0 obs[2] and NADLC1 obs[5]
% NAN from mean of NANLC0 obs[3]and NANLC1 obs[6]
% OND from ONDPC0 obs[4]
% Q-scores are averaged only for groups where GVs were provided for platforms
% No output files produced to avoid ambiguity related to adjustments
% Reviewed and re-verified by Connor on 2020-10-18

%v3: Added LIC
% QIS(GV,GRP,TYP,PFM,OBI,SFC,REZ)
% OQS(gv[65],pfm[4],obi[3],sfc[2],obj[4])
OBI = ["NADLC0", "NADBC0", "NANLC0", "ONDPC0",...
    "NADLC1","NANLC1","NADLC2","NANLC2"];  
pfm = ["SSP0","SSP1","SSP2","SSG3"];
OQS = NaN([65,4,3,2,4]);
OCW = ACCP_Obj_Case_Weights;

[~, ~, GVnames] = xlsread([getnamedpath('ACCP'),'GVnames.SIT-A_Sept.xlsx'],'Sheet1');
GVnames = string(GVnames);
GVnames(ismissing(GVnames)) = '';
gv = [1:length(GVnames)];

% Map the enumerated Objective cases to indices in GIS
% Ocean_cases= ["8a","8b","8c","8g","8h","8k","8l"]; [a:c g:h k:l] [1:3 7:8 11:12]
% Land_cases= ["8d","8e","8f","8i","8j","8m","8n","8o"]; [d:f i:j m:o] [4:6 9:10 13:15]
ocen_case = [1:3 7:8 11:12];
land_case = [4:6 9:10 13:15];
case1 = 0; case2 = 15;
DRS = 0; ICA = 30;

DRS_land_cases = [case1+land_case  case2+land_case];
ICA_land_cases = ICA + [case1+land_case  case2+land_case];

DRS_ocen_cases = [ocen_case  case2+ocen_case];
ICA_ocen_cases = ICA+[ocen_case  case2+ocen_case];

OCW_land = OCW(land_case,:); OCW_lands = [OCW_land;OCW_land]; % Obj6, Land, Ocen are effectively unweighted
OCW_ocen = OCW(ocen_case,:); OCW_ocens = [OCW_ocen;OCW_ocen];
GRP = ["NLP", "NLB", "NLS", "NGE", "OUX","LIC"];                  %5
%% NLP-DRSall is QIS(h, 1, DRS_cases, :, L, m, n)
%% NLS-DRSall is QIS(h, 3, DRS_cases, :, L, m, n)
%% NGE-DRSall is QIS(h, 4, DRS_cases, :, L, m, n)
%% OUX-DRSall is QIS(h, 5, DRS_cases, :, L, m, n)
%% NLB-ICAall is QIS(h, 2, ICA_cases, :, L, m, n)

% This averaging has to be done carefully since we only want to use results
% for which all four platforms are defined, and we want to use the
% GV-specific SATM RES when available else default to RES=1

for OO = 1:4
    for sfc = 1:2
        if sfc == 1
            DRS_cases = DRS_land_cases;
            ICA_cases = ICA_land_cases;
            OCWs = OCW_lands(:,OO);
        else
            DRS_cases = DRS_ocen_cases;
            ICA_cases = ICA_ocen_cases;
            OCWs = OCW_ocens(:,OO);
        end
        for H = gv
            R = 1;
            %RES4 for GV52-55, RES5 for GV50-51
            if H>=50&&H<=51
                % RES5
                R = 5;
            elseif H>=52 && H<= 55
                R = 4;
            end
            
            L = 5; % for NADLC1
            grp = 1; % NLP-DRSall is QIS(h, 1, DRS_cases, :, L, m, n)
            QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_1)) &&R~=1
                QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 3;% NLS-DRSall is QIS(h, 3, DRS_cases, :, L, m, n)
            QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_2)) &&R~=1
                QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 4;% NGE-DRSall is QIS(h, 4, DRS_cases, :, L, m, n)
            QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_3)) &&R~=1
                QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 5; % OUX-DRSall is QIS(h, 5, DRS_cases, :, L, m, n)
            QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_4)) &&R~=1
                QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =2; % NLB-ICAall is QIS(h, 2, ICA_cases, :, L, m, n)
            QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, R));
            OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_5)) &&R~=1
                QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, 1));
                OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            end

            grp =6; NR1 = 63; % LIC NR1 is QIS(h, 6, 63, :, L, m, n)
            QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, R));
            OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            if all(isNaN(OQ_6)) &&R~=1
                QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, 1));
                OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            end
            
            new_OQ = [OQ_1; OQ_2; OQ_3; OQ_4; OQ_5; OQ_6]; % old, newQIS 8x4, so now 6x4?
            % Only use cases where all 4 platforms are reported
            ONAN = double(~isNaN(new_OQ));
            ONAN(isNaN(new_OQ)) = NaN; anyNaN = any(isNaN(ONAN)')'; ONAN(anyNaN,:) = NaN;
            meanOQ_NADLC1 = meannonan(new_OQ.*ONAN)./mean(OCWs); % These are mean Qs for this GV and Objective weights.
            %OQS(obj,gv,obs,sfc,pltf)
            
            L = 2; % for NADBC0
            grp = 1; % NLP-DRSall is QIS(h, 1, DRS_cases, :, L, m, n)
            QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_1)) &&R~=1
                QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 3;% NLS-DRSall is QIS(h, 3, DRS_cases, :, L, m, n)
            QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_2)) &&R~=1
                QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 4;% NGE-DRSall is QIS(h, 4, DRS_cases, :, L, m, n)
            QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_3)) &&R~=1
                QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 5; % OUX-DRSall is QIS(h, 5, DRS_cases, :, L, m, n)
            QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_4)) &&R~=1
                QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =2; % NLB-ICAall is QIS(h, 2, ICA_cases, :, L, m, n)
            QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, R));
            OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_5)) &&R~=1
                QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, 1));
                OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =6; NR1 = 63; % LIC NR1 is QIS(h, 6, 63, :, L, m, n)
            QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, R));
            OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            if all(isNaN(OQ_6)) &&R~=1
                QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, 1));
                OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            end
            
            new_OQ = [OQ_1; OQ_2; OQ_3; OQ_4; OQ_5; OQ_6]; % old, newQIS 8x4, so now 6x4?
            % Only use cases where all 4 platforms are reported
            ONAN = double(~isNaN(new_OQ));
            ONAN(isNaN(new_OQ)) = NaN; anyNaN = any(isNaN(ONAN)')'; ONAN(anyNaN,:) = NaN;
            meanOQ_NADBC0 = meannonan(new_OQ.*ONAN)./mean(OCWs); % These are mean Qs for this GV and Objective weights.
            
            L = 1; % for NADLC0
            grp = 1; % NLP-DRSall is QIS(h, 1, DRS_cases, :, L, m, n)
            QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_1)) &&R~=1
                QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 3;% NLS-DRSall is QIS(h, 3, DRS_cases, :, L, m, n)
            QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_2)) &&R~=1
                QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 4;% NGE-DRSall is QIS(h, 4, DRS_cases, :, L, m, n)
            QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_3)) &&R~=1
                QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 5; % OUX-DRSall is QIS(h, 5, DRS_cases, :, L, m, n)
            QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_4)) &&R~=1
                QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =2; % NLB-ICAall is QIS(h, 2, ICA_cases, :, L, m, n)
            QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, R));
            OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_5)) &&R~=1
                QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, 1));
                OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =6; NR1 = 63; % LIC NR1 is QIS(h, 6, 63, :, L, m, n)
            QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, R));
            OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            if all(isNaN(OQ_6)) &&R~=1
                QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, 1));
                OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            end
            
            new_OQ = [OQ_1; OQ_2; OQ_3; OQ_4; OQ_5; OQ_6]; % old, newQIS 8x4, so now 6x4?
            % Only use cases where all 4 platforms are reported
            ONAN = double(~isNaN(new_OQ));
            ONAN(isNaN(new_OQ)) = NaN; anyNaN = any(isNaN(ONAN)')'; ONAN(anyNaN,:) = NaN;
            meanOQ_NADLC0 = meannonan(new_OQ.*ONAN)./mean(OCWs); % These are mean Qs for this GV and Objective weights.
            
            temp = nanmean([meanOQ_NADLC1; meanOQ_NADBC0]);
            % OQS(gv,pfm,obi,sfc,obj(4))
            OQS(H,:,1,sfc,OO) = temp;
            
            L = 3; % for NANLC0
            grp = 1; % NLP-DRSall is QIS(h, 1, DRS_cases, :, L, m, n)
            QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_1)) &&R~=1
                QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 3;% NLS-DRSall is QIS(h, 3, DRS_cases, :, L, m, n)
            QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_2)) &&R~=1
                QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 4;% NGE-DRSall is QIS(h, 4, DRS_cases, :, L, m, n)
            QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_3)) &&R~=1
                QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 5; % OUX-DRSall is QIS(h, 5, DRS_cases, :, L, m, n)
            QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_4)) &&R~=1
                QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =2; % NLB-ICAall is QIS(h, 2, ICA_cases, :, L, m, n)
            QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, R));
            OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_5)) &&R~=1
                QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, 1));
                OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =6; NR1 = 63; % LIC NR1 is QIS(h, 6, 63, :, L, m, n)
            QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, R));
            OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            if all(isNaN(OQ_6)) &&R~=1
                QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, 1));
                OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            end
            
            new_OQ = [OQ_1; OQ_2; OQ_3; OQ_4; OQ_5; OQ_6]; % old, newQIS 8x4, so now 6x4?
            % Only use cases where all 4 platforms are reported
            ONAN = double(~isNaN(new_OQ));
            ONAN(isNaN(new_OQ)) = NaN; anyNaN = any(isNaN(ONAN)')'; ONAN(anyNaN,:) = NaN;
            meanOQ_NANLC0 = meannonan(new_OQ.*ONAN)./mean(OCWs); % These are mean Qs for this GV and Objective weights.
            
            L = 6; % for NANLC1
            grp = 1; % NLP-DRSall is QIS(h, 1, DRS_cases, :, L, m, n)
            QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_1)) &&R~=1
                QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 3;% NLS-DRSall is QIS(h, 3, DRS_cases, :, L, m, n)
            QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_2)) &&R~=1
                QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 4;% NGE-DRSall is QIS(h, 4, DRS_cases, :, L, m, n)
            QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_3)) &&R~=1
                QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 5; % OUX-DRSall is QIS(h, 5, DRS_cases, :, L, m, n)
            QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_4)) &&R~=1
                QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =2; % NLB-ICAall is QIS(h, 2, ICA_cases, :, L, m, n)
            QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, R));
            OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_5)) &&R~=1
                QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, 1));
                OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =6; NR1 = 63; % LIC NR1 is QIS(h, 6, 63, :, L, m, n)
            QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, R));
            OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            if all(isNaN(OQ_6)) &&R~=1
                QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, 1));
                OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            end
            
            new_OQ = [OQ_1; OQ_2; OQ_3; OQ_4; OQ_5; OQ_6]; % old, newQIS 8x4, so now 6x4?
            % Only use cases where all 4 platforms are reported
            ONAN = double(~isNaN(new_OQ));
            ONAN(isNaN(new_OQ)) = NaN; anyNaN = any(isNaN(ONAN)')'; ONAN(anyNaN,:) = NaN;
            meanOQ_NANLC1 = meannonan(new_OQ.*ONAN)./mean(OCWs); % These are mean Qs for this GV and Objective weights.
            temp = nanmean([meanOQ_NANLC0; meanOQ_NANLC1]);
            
            OQS(H,:,2,sfc,OO) = temp;
            
            
            L = 4; % for ONDPC0
            grp = 1; % NLP-DRSall is QIS(h, 1, DRS_cases, :, L, m, n)
            QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_1)) &&R~=1
                QI_1 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_1 = nanmean(QI_1.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 3;% NLS-DRSall is QIS(h, 3, DRS_cases, :, L, m, n)
            QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_2)) &&R~=1
                QI_2 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_2 = nanmean(QI_2.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 4;% NGE-DRSall is QIS(h, 4, DRS_cases, :, L, m, n)
            QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_3)) &&R~=1
                QI_3 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_3 = nanmean(QI_3.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp = 5; % OUX-DRSall is QIS(h, 5, DRS_cases, :, L, m, n)
            QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, R));
            OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_4)) &&R~=1
                QI_4 = squeeze(QIS(H, grp, DRS_cases,  :,L, sfc, 1));
                OQ_4 = nanmean(QI_4.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =2; % NLB-ICAall is QIS(h, 2, ICA_cases, :, L, m, n)
            QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, R));
            OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            if all(isNaN(OQ_5)) &&R~=1
                QI_5 = squeeze(QIS(H, grp, ICA_cases,  :,L, sfc, 1));
                OQ_5 = nanmean(QI_5.*(OCWs*ones([1,length(pfm)])));
            end
            
            grp =6; NR1 = 63; % LIC NR1 is QIS(h, 6, 63, :, L, m, n)
            QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, R));
            OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            if all(isNaN(OQ_6)) &&R~=1
                QI_6 = squeeze(QIS(H, grp, NR1,  :,L, sfc, 1));
                OQ_6 = nanmean(QI_6.*(mean(OCWs)*ones([1,length(pfm)])),2)';
            end
            
            new_OQ = [OQ_1; OQ_2; OQ_3; OQ_4; OQ_5; OQ_6]; % old, newQIS 8x4, so now 6x4?4?
            % Only use cases where all 4 platforms are reported
            ONAN = double(~isNaN(new_OQ));
            ONAN(isNaN(new_OQ)) = NaN; anyNaN = any(isNaN(ONAN)')'; ONAN(anyNaN,:) = NaN;
            meanOQ_ONDPC0 = meannonan(new_OQ.*ONAN)./mean(OCWs); % These are mean Qs for this GV and Objective weights.
            OQS(H,:,3,sfc,OO) = meanOQ_ONDPC0;
            %OQS(obj,gv,obs,sfc,pltf
            
        end %of OWC loop
    end
end
% apply zero min, unity max to OQS
OQS(OQS<0)=0; OQS(OQS>1)=1;


return
