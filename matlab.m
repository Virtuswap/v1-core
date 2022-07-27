clear all;
format long;


%************************************************************************************************************************************************************;

% starting conditions;

% initial prices;

epsilon=0.000001;

number_currencies=4;

number_liquidity_providers=5; 

P(1)=1;
P(2)=0.5;
P(3)=1.5;
P(4)=0.7;

% assigning fees to real pools and virtual
for i=1:number_currencies
    for j=1:number_currencies
        if j>i
            fee_R(i,j)=0.002;
            fee_V(i,j)=0.003;
        end;
        if j<i
            fee_R(i,j)=fee_R(j,i);
            fee_V(i,j)=fee_V(j,i);
        end;
    end;
end;
         

% assigning values to the maximum reserve ratio;

for i=1:number_currencies
    for j=1:number_currencies
        if j>i
            max_reserve_ratio(i,j)=0.02;
        end;
        if j<i
            max_reserve_ratio(i,j)=max_reserve_ratio(j,i);
        end;
    end;
end;



% initial liquidity provision
%asset1:asset2:asset1 qnt

R(1,2,1)=100;
R(1,3,1)=130;
R(1,4,1)=30;
R(2,3,2)=0;
R(2,4,2)=600;
R(3,4,3)=150;

%calculate asset2 quantity according to price
for i=1:number_currencies;
    for j=1:number_currencies;
        if i<j
            R(i,j,j)=R(i,j,i)*P(i)/P(j);
        end;
        if j<i
            R(i,j,i)=R(j,i,i);
            R(i,j,j)=R(j,i,j);
        end;
        for k=1:number_currencies
            if (k~=i & k~=j)
                R(i,j,k)=0;
            end;
        end;
    end;
end;

% initial reserve to native tokens ratio
% reserve ratio calculation 
for i=1:number_currencies
    for j=1:number_currencies
        if i<j
            reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=reserve_ratio(i,j)+R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                end;
            end;
        end;
        if j<i
            reserve_ratio(i,j)=reserve_ratio(j,i);
        end;
    end;
end;

% initial "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;

%TODO: algorithm to calculate what below thresholds should be calculated


% initial virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% initial total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% initial average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;


% Initial pool ownership

t(1,2,1)=1;
t(1,3,2)=1;
t(1,4,3)=1;
t(2,4,4)=1;
t(3,4,5)=1;

for i=2:number_currencies
    for j=1:i-1
        for k=1:number_liquidity_providers
            t(i,j,k)=t(j,i,k);
        end;
    end;
end;
       




%************************************************************************************************************************************************************;




% Trading 1 (in completely virtual pool BC);

% Trading on the BC (total pool) curve;


buy_currency=2;
sell_currency=3;
Buy=30;

%save current values
lag_T(buy_currency,sell_currency,buy_currency)=T(buy_currency,sell_currency,buy_currency);
lag_T(buy_currency,sell_currency,sell_currency)=T(buy_currency,sell_currency,sell_currency);

%add fees to amount_in
T(buy_currency,sell_currency,buy_currency)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-fee_T(buy_currency,sell_currency));

%calculate amount_out
T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy);

%TUDO: check in uniswap if fee is from input or output token

% Updating of BC real pool;

for k=1:number_currencies
    lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
end;

%take buy_currency proportional from real and virtual pool 
R(buy_currency,sell_currency,buy_currency)=lag_R(buy_currency,sell_currency,buy_currency)*T(buy_currency,sell_currency,buy_currency)/lag_T(buy_currency,sell_currency,buy_currency);

%take sell_currency proportional from real and virtual pool 
R(buy_currency,sell_currency,sell_currency)=lag_R(buy_currency,sell_currency,sell_currency)*T(buy_currency,sell_currency,sell_currency)/lag_T(buy_currency,sell_currency,sell_currency);

%fill reverse 
R(sell_currency,buy_currency,buy_currency)=R(buy_currency,sell_currency,buy_currency);
R(sell_currency,buy_currency,sell_currency)=R(buy_currency,sell_currency,sell_currency);



% Updating of non-native pools that contribute to BC virtual pool;

i=buy_currency;
for k=1:number_currencies
    if (k~=buy_currency & k~=sell_currency)
        aaa = sum(lag_R(buy_currency,1:number_currencies,buy_currency);
        R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency)+((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-(R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*lag_R(buy_currency,k,buy_currency)/(aaa)-lag_R(buy_currency,sell_currency,buy_currency));
      
      %fill reverse pool
        R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    end;
end;



% Updating reserves of real pools and all the subsequent calculations;

i=buy_currency;
for k=1:number_currencies
    if (k~=buy_currency & k~=sell_currency)
        R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency)+((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-(R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-lag_R(buy_currency,sell_currency,buy_currency));
        R(k,buy_currency,sell_currency)=R(buy_currency,k,sell_currency);
    end;
end;


% Update of reserve to native tokens ratio
for i=1:number_currencies
    for j=1:number_currencies
        reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=reserve_ratio(i,j)+R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                    reserve_ratio(j,i)=reserve_ratio(i,j);
                end;
            end;
    end;
end;

% Update of "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;



% Update of virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% Update of total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% Update of average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;





%************************************************************************************************************************************************************;





% Trading 2 (in mixed pool AB)

% Trading on the AB (total pool) curve;


buy_currency=1;
sell_currency=2;
Buy=40;


lag_T(buy_currency,sell_currency,buy_currency)=T(buy_currency,sell_currency,buy_currency);
lag_T(buy_currency,sell_currency,sell_currency)=T(buy_currency,sell_currency,sell_currency);

T(buy_currency,sell_currency,buy_currency)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-fee_T(buy_currency,sell_currency));
T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy);


% Updating of AB real pool;

for k=1:number_currencies
    lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
end;

R(buy_currency,sell_currency,buy_currency)=lag_R(buy_currency,sell_currency,buy_currency)*T(buy_currency,sell_currency,buy_currency)/lag_T(buy_currency,sell_currency,buy_currency);
R(buy_currency,sell_currency,sell_currency)=lag_R(buy_currency,sell_currency,sell_currency)*T(buy_currency,sell_currency,sell_currency)/lag_T(buy_currency,sell_currency,sell_currency);
R(sell_currency,buy_currency,buy_currency)=R(buy_currency,sell_currency,buy_currency);
R(sell_currency,buy_currency,sell_currency)=R(buy_currency,sell_currency,sell_currency);


% Updating of non-native pools that contribute to AB virtual pool;

i=buy_currency;
for k=1:number_currencies
    if (k~=buy_currency & k~=sell_currency)
        R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency)+((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-(R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-lag_R(buy_currency,sell_currency,buy_currency));
        R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    end;
end;


% Updating reserves of real pools and all the subsequent calculations;

i=buy_currency;
for k=1:number_currencies
    if (k~=buy_currency & k~=sell_currency)
        R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency)+((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-(R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-lag_R(buy_currency,sell_currency,buy_currency));
        R(k,buy_currency,sell_currency)=R(buy_currency,k,sell_currency);
    end;
end;


% Update of reserve to native tokens ratio

for i=1:number_currencies
    for j=1:number_currencies
        reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=reserve_ratio(i,j)+R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                    reserve_ratio(j,i)=reserve_ratio(i,j);
                end;
            end;
    end;
end;

% Update of "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;



% Update of virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% Update of total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% Update of average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;




%************************************************************************************************************************************************************;


% Return of reserves to native pools;

% Exchanging reserves;

for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_currencies
            lag_R(i,j,k)=R(i,j,k);
            lag_R(j,i,k)=lag_R(i,j,k);
        end;
    end;
end;


for i=1:number_currencies
    for j=1:number_currencies
        for k=1:number_currencies
            if (k~=i & k~=j & R(i,j,k)>0 & R(i,k,j)>0)
                lag_R(i,j,k)=R(i,j,k);
                lag_R(i,k,j)=R(i,k,j);
                lag_R(i,j,j)=R(i,j,j);
                lag_R(i,k,k)=R(i,k,k);
                
                R(i,j,k)=lag_R(i,j,k)-min(lag_R(i,j,k),lag_R(i,k,j)*lag_R(i,k,k)/lag_R(i,k,i)*lag_R(i,j,i)/lag_R(i,j,j));
                R(i,k,j)=lag_R(i,k,j)-min(lag_R(i,k,j),lag_R(i,j,k)*lag_R(i,j,j)/lag_R(i,j,i)*lag_R(i,k,i)/lag_R(i,k,k));
                R(i,j,j)=lag_R(i,j,j)+lag_R(i,k,j)-R(i,k,j);
                R(i,k,k)=lag_R(i,k,k)+lag_R(i,j,k)-R(i,j,k);

                R(j,i,k)=R(i,j,k);
                R(k,i,j)=R(i,k,j);
                R(j,i,j)=R(i,j,j);
                R(k,i,k)=R(i,k,k);
            end;
        end;
    end;
end;



% Update of reserve to native tokens ratio

for i=1:number_currencies
    for j=1:number_currencies
        reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=reserve_ratio(i,j)+R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                    reserve_ratio(j,i)=reserve_ratio(i,j);
                end;
            end;
    end;
end;

% Update of "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;



% Update of virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% Update of total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% Update of average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;





%************************************************************************************************************************************************************;


% Addition of liquidity;

% LP 4 adds 80 A to pool AC;

% update of real pool;

add_currency_base=1;
add_currency_quote=3;
Add=80;
LP=4;

lag_R(add_currency_base,add_currency_quote,add_currency_base)=R(add_currency_base,add_currency_quote,add_currency_base);
lag_R(add_currency_base,add_currency_quote,add_currency_quote)=R(add_currency_base,add_currency_quote,add_currency_quote);
R(add_currency_base,add_currency_quote,add_currency_base)=lag_R(add_currency_base,add_currency_quote,add_currency_base)+Add;
R(add_currency_base,add_currency_quote,add_currency_quote)=lag_R(add_currency_base,add_currency_quote,add_currency_quote)+Add*lag_R(add_currency_base,add_currency_quote,add_currency_quote)/lag_R(add_currency_base,add_currency_quote,add_currency_base);
R(add_currency_quote,add_currency_base,add_currency_base)=R(add_currency_base,add_currency_quote,add_currency_base);
R(add_currency_quote,add_currency_base,add_currency_quote)=R(add_currency_base,add_currency_quote,add_currency_quote);





% Update of reserve to native tokens ratio

for i=1:number_currencies
    for j=1:number_currencies
        reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=reserve_ratio(i,j)+R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                    reserve_ratio(j,i)=reserve_ratio(i,j);
                end;
            end;
    end;
end;

% Update of "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;



% Update of virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% Update of total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% Update of average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;


% Update of pool ownership by LPs;

for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_liquidity_providers
            lag_t(i,j,k)=t(i,j,k);
        end;
    end;
end;

t(add_currency_base,add_currency_quote,LP)=lag_t(add_currency_base,add_currency_quote,LP)+Add*sum(lag_t(add_currency_base,add_currency_quote,:))/(lag_R(add_currency_base,add_currency_quote,add_currency_base)*(1+reserve_ratio(add_currency_base,add_currency_quote)*(1+Add/lag_R(add_currency_base,add_currency_quote,add_currency_base))));
t(add_currency_quote,add_currency_base,LP)=t(add_currency_base,add_currency_quote,LP);






%************************************************************************************************************************************************************;


% Withdrawal of liquidity;

% Assume LP2 wishes to withdraw 40% of his liquidity from pool AC

withdraw1=1;
withdraw2=3;
LP=2;
prop_withdrawal=0.4;

for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_liquidity_providers
            lag_t(i,j,k)=t(i,j,k);
        end;
    end;
end;

t(withdraw1,withdraw2,LP)=lag_t(withdraw1,withdraw2,LP)*(1-prop_withdrawal);

% 1.sale of proportional share of A and C from non-native pools through pool AC;

% 1a. removal of proportional share of A and C from non-native pools;

for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_currencies
            lag_R(i,j,k)=R(i,j,k);
            lag_R(j,i,k)=lag_R(i,j,k);
        end;
    end;
end;

for i=1:number_currencies
    Total_removed(i)=0;
end;

for i=1:number_currencies
    for j=1:number_currencies
        for k=1:number_currencies
            Removed_share(i,j,k)=0;
        end;
    end;
end;
         

for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_currencies
            if (k~=i & k~=j & (k==withdraw1 | k==withdraw2))
                lag_R(i,j,k)=R(i,j,k);
                R(i,j,k)=lag_R(i,j,k)*(1-prop_withdrawal*lag_t(withdraw1,withdraw2,LP)/sum(lag_t(withdraw1,withdraw2,:)));
                Total_removed(k)=Total_removed(k)+(lag_R(i,j,k)-R(i,j,k));
            end;
        end;
    end;
end;

for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_currencies
            if (k~=i & k~=j & (k==withdraw1 | k==withdraw2))
                Removed_share(i,j,k)=(lag_R(i,j,k)-R(i,j,k))/max(Total_removed(k),epsilon);
                Removed_share(j,i,k)=Removed_share(i,j,k);
            end;
        end;
    end;
end;


% 1b. substitition of removed A and C on real pool AC, putting resulting A and C in a temporary holding tanks, and return of A to all pools that held C reserves

for i=1:number_currencies
    Holding_tank(i)=0;
end;


lag_R(withdraw1,withdraw2,withdraw1)=R(withdraw1,withdraw2,withdraw1);
lag_R(withdraw1,withdraw2,withdraw2)=R(withdraw1,withdraw2,withdraw2);

R(withdraw1,withdraw2,withdraw1)=lag_R(withdraw1,withdraw2,withdraw1)+Total_removed(withdraw1);
R(withdraw1,withdraw2,withdraw2)=lag_R(withdraw1,withdraw2,withdraw1)*lag_R(withdraw1,withdraw2,withdraw2)/R(withdraw1,withdraw2,withdraw1);
R(withdraw2,withdraw1,withdraw1)=R(withdraw1,withdraw2,withdraw1);
R(withdraw2,withdraw1,withdraw2)=R(withdraw1,withdraw2,withdraw2);

Holding_tank(withdraw2)=lag_R(withdraw1,withdraw2,withdraw2)-R(withdraw1,withdraw2,withdraw2);




for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_currencies
            if i~=withdraw1 & i~=withdraw2 & j~=withdraw1 & j~=withdraw2
                lag_R(i,j,withdraw2)=R(i,j,withdraw2);
                R(i,j,withdraw2)=lag_R(i,j,withdraw2)+Holding_tank(withdraw2)*Removed_share(i,j,withdraw1);
                R(j,i,withdraw2)=R(i,j,withdraw2);
            end;
        end;
    end;
end;


lag_R(withdraw1,withdraw2,withdraw1)=R(withdraw1,withdraw2,withdraw1);
lag_R(withdraw1,withdraw2,withdraw2)=R(withdraw1,withdraw2,withdraw2);

R(withdraw1,withdraw2,withdraw2)=lag_R(withdraw1,withdraw2,withdraw2)+Total_removed(withdraw2);
R(withdraw1,withdraw2,withdraw1)=lag_R(withdraw1,withdraw2,withdraw1)*lag_R(withdraw1,withdraw2,withdraw2)/R(withdraw1,withdraw2,withdraw2);
R(withdraw2,withdraw1,withdraw1)=R(withdraw1,withdraw2,withdraw1);
R(withdraw2,withdraw1,withdraw2)=R(withdraw1,withdraw2,withdraw2);

Holding_tank(withdraw1)=lag_R(withdraw1,withdraw2,withdraw1)-R(withdraw1,withdraw2,withdraw1);





for i=1:number_currencies-1
    for j=i+1:number_currencies
        for k=1:number_currencies
            if i~=withdraw1 & i~=withdraw2 & j~=withdraw1 & j~=withdraw2
                lag_R(i,j,withdraw2)=R(i,j,withdraw2);
                R(i,j,withdraw1)=lag_R(i,j,withdraw1)+Holding_tank(withdraw1)*Removed_share(i,j,withdraw2);
                R(j,i,withdraw1)=R(i,j,withdraw1);
            end;
        end;
    end;
end;


% 3. Return of reserves to native pools;

% Exchanging reserves;


for i=1:number_currencies
    for j=1:number_currencies
        for k=1:number_currencies
            if (k~=i & k~=j & R(i,j,k)>0 & R(i,k,j)>0)
                lag_R(i,j,k)=R(i,j,k);
                lag_R(i,k,j)=R(i,k,j);
                lag_R(i,j,j)=R(i,j,j);
                lag_R(i,k,k)=R(i,k,k);
                R(i,j,k)=lag_R(i,j,k)-min(lag_R(i,j,k),lag_R(i,k,j)*R(i,k,k)/R(i,k,i)*R(i,j,i)/R(i,j,j));
                R(i,k,j)=lag_R(i,k,j)-min(lag_R(i,k,j),lag_R(i,j,k)*R(i,j,j)/R(i,j,i)*R(i,k,i)/R(i,k,k));
                R(i,j,j)=lag_R(i,j,j)+lag_R(i,k,j)-R(i,k,j);
                R(i,k,k)=lag_R(i,k,k)+lag_R(i,j,k)-R(i,j,k);
                R(j,i,k)=R(i,j,k);
                R(k,i,j)=R(i,k,j);
                R(j,i,j)=R(i,j,j);
                R(k,i,k)=R(i,k,k);        
            end;
        end;
    end;
end;





% Update of reserve to native tokens ratio

for i=1:number_currencies
    for j=1:number_currencies
        reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=reserve_ratio(i,j)+R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                    reserve_ratio(j,i)=reserve_ratio(i,j);
                end;
            end;
    end;
end;

% Update of "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;



% Update of virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% Update of total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% Update of average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;





% 3. Proportional withdrawal from real pool AC and update of the number of tokens of LP2;

lag_R(withdraw1,withdraw2,withdraw1)=R(withdraw1,withdraw2,withdraw1);
lag_R(withdraw1,withdraw2,withdraw2)=R(withdraw1,withdraw2,withdraw2);
R(withdraw1,withdraw2,withdraw1)=lag_R(withdraw1,withdraw2,withdraw1)*(1-prop_withdrawal*lag_t(withdraw1,withdraw2,LP)/sum(lag_t(withdraw1,withdraw2,:))*(1+0.5*reserve_ratio(withdraw1,withdraw2)));
R(withdraw1,withdraw2,withdraw2)=lag_R(withdraw1,withdraw2,withdraw2)*(1-prop_withdrawal*lag_t(withdraw1,withdraw2,LP)/sum(lag_t(withdraw1,withdraw2,:))*(1+0.5*reserve_ratio(withdraw1,withdraw2)));
R(withdraw2,withdraw1,withdraw1)=R(withdraw1,withdraw2,withdraw1);
R(withdraw2,withdraw1,withdraw2)=R(withdraw1,withdraw2,withdraw2);


% Update of virtual pools and all the rest;



% Update of reserve to native tokens ratio

for i=1:number_currencies
    for j=1:number_currencies
        reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                    reserve_ratio(j,i)=reserve_ratio(i,j);
                end;
            end;
    end;
end;

% Update of "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;



% Update of virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% Update of total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% Update of average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;





%************************************************************************************************************************************************************;


% Periodic emptying of reserves on all pools;




for i=1:number_currencies
    for j=1:number_currencies
        for k=1:number_currencies
%             lag_R(i,k,k)=R(i,k,k);
%             lag_R(i,j,k)=R(i,j,k);
%             lag_R(j,k,k)=R(j,k,k);
%             lag_R_(i,k,i)=R(i,k,i);
%             lag_R_(i,j,i)=R(i,j,i);
%             lag_R_(j,k,j)=R(j,k,j);
%             lag_R_(i,j,j)=R(i,j,j);
% 
%             lag_R(k,i,k)=R(k,i,k);
%             lag_R(j,i,k)=R(j,i,k);
%             lag_R(k,j,k)=R(k,j,k);
%             lag_R_(k,i,i)=R(k,i,i);
%             lag_R_(j,i,i)=R(j,i,i);
%             lag_R_(k,j,j)=R(k,j,j);
%             lag_R_(j,i,j)=R(j,i,j);
            for i1=1:number_currencies
                for j1=1:number_currencies
                    for k1=1:number_currencies
                        lag_R(i1,j1,k1)=R(i1,j1,k1);
                    end;
                end;
            end;


            

            if (k~=i & k~=j & R(i,j,k)>0)
                R(i,j,k)=0;

                R(i,k,k)=lag_R(i,k,k)+lag_R(i,j,k)*(lag_R(i,k,k)/max(lag_R(i,k,k)+lag_R(j,k,k),epsilon));
                R(i,k,i)=lag_R(i,k,i)*lag_R(i,k,k)/max(R(i,k,k),epsilon);
                R(i,j,i)=lag_R(i,j,i)+(lag_R(i,k,i)-R(i,k,i));

                R(j,k,k)=lag_R(j,k,k)+lag_R(i,j,k)*(lag_R(j,k,k)/max(lag_R(i,k,k)+lag_R(j,k,k),epsilon));
                R(j,k,j)=lag_R(j,k,j)*lag_R(j,k,k)/max(R(j,k,k),epsilon);
                R(i,j,j)=lag_R(i,j,j)+(lag_R(j,k,j)-R(j,k,j));

                R(j,i,k)=R(i,j,k);
                R(k,i,k)=R(i,k,k);
                R(k,i,i)=R(i,k,i);
                R(j,i,i)=R(i,j,i);
                R(k,j,k)=R(j,k,k);
                R(k,j,j)=R(j,k,j);
                R(j,i,j)=R(i,j,j);
            end;
        end;
    end;
end;




% Update of virtual pools and all the rest;



% Update of reserve to native tokens ratio

for i=1:number_currencies
    for j=1:number_currencies
        reserve_ratio(i,j)=0;
            for k=1:number_currencies
                if (k~=i & k~=j)
                    reserve_ratio(i,j)=reserve_ratio(i,j)+R(i,j,k)*max(R(i,k,i)/max(R(i,k,k),epsilon),R(j,k,j)/max(R(j,k,k),epsilon)*R(i,j,i)/max(R(i,j,j),epsilon))/(2*max(R(i,j,i),epsilon));
                    reserve_ratio(j,i)=reserve_ratio(i,j);
                end;
            end;
    end;
end;

% Update of "below threshold" indicator;

for i=1:number_currencies
    for j=1:number_currencies
        if i~=j
            ind_below_reserve_threshold(i,j)=0;
            if reserve_ratio(i,j)<max_reserve_ratio(i,j)
                ind_below_reserve_threshold(i,j)=1;
            end;
        end;
    end;
end;



% Update of virtual pools computation;

for i=1:number_currencies-1
    for j=i:number_currencies
        V(i,j,i)=0;
        V(i,j,j)=0;
        V(j,i,i)=0;
        V(j,i,j)=0;
        for k=1:number_currencies
            if (k~=i & k~=j)
                V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
                V(j,i,i)=V(j,i,i)+ind_below_reserve_threshold(j,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
                V(j,i,j)=V(j,i,j)+ind_below_reserve_threshold(j,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            end;
        end;
    end;
end;

% Update of total pools computation;

for i=1:number_currencies
    for j=1:number_currencies
        T(i,j,i)=R(i,j,i)+V(i,j,i);
        T(i,j,j)=R(i,j,j)+V(i,j,j);
    end;
end;


% Update of average fees computation;

for i=1:number_currencies
    for j=1:number_currencies
        fee_T(i,j)=(fee_R(i,j)*R(i,j,i)+fee_V(i,j)*V(i,j,i))/T(i,j,i);
    end;
end;







