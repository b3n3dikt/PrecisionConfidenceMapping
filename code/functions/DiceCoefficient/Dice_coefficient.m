function DC = Dice_coefficient(A_binary, B_binary)
    AB = A_binary .* B_binary;
    DC = 2 * sum(AB(:)) / (sum(A_binary(:)) + sum(B_binary(:)));
end