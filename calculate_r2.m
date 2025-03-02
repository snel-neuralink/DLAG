function [r2] = calculate_r2(seq,res)

    yDims = res.yDims;
    sidx = [1, yDims(1)+1];
    eidx = [yDims(1), yDims(1) + yDims(2)];
    ySeq = [seq.y];
    xDim_total = res.xDim_within + res.xDim_across;
    groupSeq = partitionObs(seq,res.xDim_across+res.xDim_within,'datafield','xsm');
    r2 = nan(1,2);
    for groupIdx=1:2
        [seqAcross, seqWithin] = partitionLatents_meanOnly(groupSeq{groupIdx}, ...
        res.xDim_across, res.xDim_within(groupIdx), 'xspec', 'xsm');
        if groupIdx == 2
            start_idx = xDim_total(groupIdx-1)+1;
        else
            start_idx = 1;
        end
            end_idx = start_idx+res.xDim_across-1;
        if res.xDim_across > 0
            across_seq = res.C(sidx(groupIdx):eidx(groupIdx),start_idx:end_idx) * [seqAcross.xsm];
            latents_sum_flat = across_seq;
        else
            latents_sum_flat = zeros(yDims(groupIdx),size(ySeq,2));
        end
        if res.xDim_within(groupIdx) > 0 
            if groupIdx == 2
                start_idx = (groupIdx-1)*xDim_total(groupIdx-1)+1+res.xDim_across;
            else
                start_idx = res.xDim_across+1;
            end
                end_idx = start_idx+res.xDim_within(groupIdx)-1;

                within_seq = res.C(sidx(groupIdx):eidx(groupIdx),start_idx:end_idx) * [seqWithin{1,1}.xsm];
            latents_sum_flat = latents_sum_flat + within_seq;
        end
        latents_sum_flat = latents_sum_flat + res.d(sidx(groupIdx):eidx(groupIdx));
        y_true = ySeq(yDims(1)*(groupIdx-1)+1:yDims(1)*(groupIdx-1)+yDims(groupIdx),:);
        r2(groupIdx) = variance_weighted_r2(y_true,latents_sum_flat);
    end

end

function r2_weighted = variance_weighted_r2(y_true, y_pred)
    % Compute the residual sum of squares (SS_res)
    ss_res = sum((y_true - y_pred).^2);
    
    % Compute the total sum of squares (SS_tot)
    ss_tot = sum((y_true - mean(y_true)).^2);
    
    % Compute the variance of each output
    variances = var(y_true);
    
    % Compute the individual R2 scores
    r2_individual = 1 - (ss_res ./ ss_tot);
    
    % Compute the weighted R2 score
    r2_weighted = sum(variances .* r2_individual) / sum(variances);
end