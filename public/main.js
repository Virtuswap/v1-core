const epsilon = 0.00000000000001;
let _tokens = [];

function getPoolIndex(rPools, tokenA, tokenB) {
  for (let i = 0; i < rPools.length; i++) {
    if (rPools[i].tokenA == tokenA && rPools[i].tokenB == tokenB) return i;
  }

  return 0;
}

function _calculateVirtualPools(rPools, tokens) {
  let vPools = [];

  // let belowReserve = _calculateBelowThreshold();
  let possiblePools = [];
  for (let i = 0; i < _tokens.length; i++) {
    for (let j = 0; j < _tokens.length; j++) {
      if (j == i) continue;
      possiblePools.push({
        tokenA: _tokens[i],
        tokenB: _tokens[j],
      });
    }
  }

  for (let i = 0; i < possiblePools.length; i++) {
    vPools.push({
      id: i + 1,
      tokenABalance: 0,
      tokenBBalance: 0,
      tokenA: possiblePools[i].tokenA,
      tokenB: possiblePools[i].tokenB,
      composition: { ks: [], js: [] },
    });

    for (let k = 0; k < tokens.length; k++) {
      // if (
      //   possiblePools[i].tokenA == tokens[k] ||
      //   possiblePools[i].tokenB == tokens[k]
      // )
      //   continue;

      let ikIndex = getPoolIndex(rPools, possiblePools[i].tokenA, tokens[k]);
      let jkIndex = getPoolIndex(rPools, possiblePools[i].tokenB, tokens[k]);

      if (ikIndex == 0 || jkIndex == 0) continue;

      // vPools[i].fee = 0.03;

      let changedA = vPools[i].tokenABalance;

      //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
      vPools[i].tokenABalance =
        vPools[i].tokenABalance +
        (1 *
          rPools[ikIndex].tokenABalance *
          Math.min(
            rPools[ikIndex].tokenBBalance,
            rPools[jkIndex].tokenBBalance
          )) /
          Math.max(rPools[ikIndex].tokenBBalance, epsilon);

      let changedB = vPools[i].tokenBBalance;

      //  V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
      vPools[i].tokenBBalance =
        vPools[i].tokenBBalance +
        (1 *
          rPools[jkIndex].tokenABalance *
          Math.min(
            rPools[ikIndex].tokenBBalance,
            rPools[jkIndex].tokenBBalance
          )) /
          Math.max(rPools[jkIndex].tokenBBalance, epsilon);

      if (
        changedA < vPools[i].tokenABalance ||
        changedB < vPools[i].tokenBBalance
      ) {
        vPools[i].composition.ks.push(ikIndex);
        vPools[i].composition.js.push(jkIndex);
      }
    }
  }

  return vPools;
}

function _calculateTotalPools(rPools, tokens) {
  let vPools = _calculateVirtualPools(rPools, tokens);
  let tPools = [];
  for (let i = 0; i < vPools.length; i++) {
    let rPoolIndex = getPoolIndex(rPools, vPools[i].tokenA, vPools[i].tokenB);

    tPools.push({ fee: 0, tokenABalance: 0, tokenBBalance: 0, id: 0 });
    tPools[i].fee = vPools[i].fee;

    tPools[i].tokenABalance = (
      rPools[rPoolIndex].tokenABalance + vPools[i].tokenABalance
    ).toFixed(3);

    tPools[i].tokenBBalance = (
      rPools[rPoolIndex].tokenBBalance + vPools[i].tokenBBalance
    ).toFixed(3);
    tPools[i].id = vPools[i].id;

    if (tPools[i].tokenABalance > 0) {
      tPools[i].fee =
        (rPools[rPoolIndex].fee * rPools[rPoolIndex].tokenABalance +
          vPools[i].fee * vPools[i].tokenABalance) /
        tPools[i].tokenABalance;
    }
  }
  return tPools;
}

function showOverlay() {
  $(".overlay").show();
}

function hideOverlay() {
  $(".overlay").hide();
}

function renderStatePanel() {
  showOverlay();
  $.get("/api/status").then((res) => {
    let stateHtml = `Contract: ${res.contractAddress}<br>
                   Account: ${res.accountAddress} (${
      res.accountBalance
    } ETH) <br>
                   Pools ${
                     res.poolsInitialized
                       ? "initialized (" + res.poolsCount + " pools)"
                       : "not initialized (0 pools)"
                   }`;

    $(".statePanel").html(stateHtml);

    if (res.poolsInitialized) {
      renderPools();
    }

    hideOverlay();
  });
}

function calculateVpools() {
  showOverlay();
  $.get("/api/calculateVpools").then((res) => {
    renderStatePanel();
    hideOverlay();
  });
}

function getTokens() {
  showOverlay();
  $.get("http://45.77.163.160:3000/api/tokens").then((res) => {
    _tokens = res;
  });
}

function exchangeReserves() {
  showOverlay();
  $.get("/api/exchangeReserves").then((res) => {
    renderStatePanel();
    hideOverlay();
  });
}

function initPools() {
  showOverlay();
  $.get("/api/initPools").then((res) => {
    renderStatePanel();
    hideOverlay();
  });
}

function calculateThreshold() {
  showOverlay();
  $.get("/api/calculateBelowThreshold").then((res) => {
    renderStatePanel();
    hideOverlay();
  });
}

async function getPoolReserves(tokenA, tokenB) {
  showOverlay();
  $.get(`/api/getPoolReserves?tokenA=${tokenA}&tokenB=${tokenB}`).then(
    (res) => {
      let reservesHtml = "";
      for (let i = 0; i < res.length; i++) {
        reservesHtml += `<tr><td>${res[i][1]}</td>
                <td>${res[i][2]}</td>
               </tr>`;
      }

      $("#poolReservesTbl tbody").html(reservesHtml);

      hideOverlay();
    }
  );
}

function showSwap() {
  $(".swapPopup").addClass("show");
  showOverlay();
}

function makeSwap() {
  let selectedinToken = document.getElementById("currencyIn").value;
  let selectedoutToken = document.getElementById("currencyOut").value;

  let amount = document.getElementById("amountIn").value;

  $(".swapPopup").removeClass("show");
  $.get(
    `/api/swap?tokenIn=${selectedinToken}&tokenOut=${selectedoutToken}&amount=${amount}`
  ).then((res) => {
    renderStatePanel();
    hideOverlay();
  });
}

function quote() {
  let selectedinToken = document.getElementById("currencyIn").value;
  let selectedoutToken = document.getElementById("currencyOut").value;

  let amount = document.getElementById("amountIn").value;

  $.get(
    `/api/quote?tokenIn=${selectedinToken}&tokenOut=${selectedoutToken}&amount=${amount}`
  ).then((res) => {
    renderStatePanel();
    alert("quote: " + res);
    hideOverlay();
  });
}

function IndirectCost() {
  $.get(`/api/costUniswapIndirect`).then((res) => {
    renderStatePanel();
    alert("quote: " + res);
    hideOverlay();
  });
}

function virtuswapCost() {
  $.get(`/api/virtuswapCost`).then((res) => {
    renderStatePanel();
    alert("quote: " + res);
    hideOverlay();
  });
}

function directCost() {
  $.get(`/api/costUniswapdirect`).then((res) => {
    renderStatePanel();
    alert("quote: " + res);
    hideOverlay();
  });
}

function testNums() {
  showOverlay();
  $.get("/api/testNums").then((res) => {
    renderStatePanel();
    hideOverlay();
  });
}

function calculateReserveRatio() {
  showOverlay();
  $.get("/api/calculateReserve").then((res) => {
    renderStatePanel();
    hideOverlay();
  });
}

function getTokenName(address) {
  switch (address) {
    case "0x9F1Cf5a75828e04BDD7993a95993F57d16969dDa":
      return "WBTC";
    case "0xe82f2afA6cFf9123755Ce5E9D28A8cb26c98D847":
      return "ETH";
    case "0x56d6129890E87B4478207e8F64f056C914b25b33":
      return "USDC";
    case "0xd5Eef3420E7BE604d6A0334B2cF215e1aec4f7ce":
      return "USDT";
    case "0xdFcE41a9855a9F8975eBFc6f4B9aedfaeB1B9641":
      return "LINK";
    case "0x94dA77Df06019aA60759cc21a3c30e5902020e88":
      return "HEX";
    case "0xb88452515D3c5E9d7EB45b103980F345f269E120":
      return "LUNA";
    case "0x41523B3000eF96B2588906B34bf255E84e9B5912":
      return "MATIC";
    case "0x76E4991C46c59f51deDEEb220932e67E5d23Fb98":
      return "SAND";
    case "0x9E726b108e7F8D8f05D21B05d0eF17bdDf2bD45F":
      return "AAVE";
    case "0x93dea6B2c2Acd1A30014aad65B7e631C51a3D95b":
      return "1INCH";
    case "0xC02FEc8833B22BEb97b24f5303fEd398216914f9":
      return "MKR";
    case "0x10D9e5B0Ae9Ac33D7fDFAc9Ee3bA4F4898fd3266":
      return "WDOGE";
    default:
      return "---";
  }
}

function renderPools() {
  showOverlay();
  $.get("http://45.77.163.160:3000/api/pools").then((res) => {
    //normalize rPool numbers
    for (let i = 0; i < res.length; i++) {
      res[i].balanceA = res[i].balanceA * 1;
      res[i].balanceB = res[i].balanceB * 1;
    }

    const vPools = _calculateVirtualPools(res, _tokens);
    // const tPools = _calculateTotalPools(res, _tokens);
    const tPools = [];

    let tableHtml = "";
    let a = res;
    for (let i = 0; i < res.length; i++) {
      tableHtml += `<tr class="rpoolToken" data-tokenA="${
        res[i].tokenA
      }" data-tokenB="${res[i].tokenB}"><td>${i}</td><td>
                    ${getTokenName(res[i].tokenA)} / ${getTokenName(
        res[i].tokenB
      )}
                </td>
                <td>
                    ${res[i].tokenABalance} / ${
        res[i].tokenBBalance
      }
                </td>
                <td>
                    ${res[i].belowReserve}
                </td>
                <td>
                    ${res[i].fee}%
                </td>
               </tr>`;
    }

    $("#rPools tbody").html(tableHtml);

    let vPoolsHtml = "";
    for (let i = 0; i < vPools.length; i++) {
      vPoolsHtml += `<tr><td>${vPools[i].id}</td><td>
                ${getTokenName(vPools[i].tokenA)} / ${getTokenName(
        vPools[i].tokenB
      )}
            </td>
            <td>
                ${vPools[i].tokenABalance.toFixed(3)} / ${vPools[
        i
      ].tokenBBalance.toFixed(3)}
            </td>
            <td>
                ${vPools[i].fee ? vPools[i].fee + "%" : ""}
            </td></tr>`;
    }

    $("#vPools tbody").html(vPoolsHtml);

    let tPoolsHtml = "";

    for (let i = 0; i < tPools.length; i++) {
      tPoolsHtml += `<tr><td>${tPools[i].id}</td>
        <td>
            ${tPools[i].tokenABalance} / ${tPools[i].tokenBBalance}
        </td>
        <td>
            ${tPools[i].fee.toFixed(3)}%
        </td></tr>`;
    }

    $("#tPools tbody").html(tPoolsHtml);

    hideOverlay();
  });
}

function clearLog() {
  $("#textArea").text("");
}

$(function () {
  renderStatePanel();

  let a = getTokens();
  $("#initPools").click(initPools);
  $("#refreshPools").click(renderPools);
  $("#calculateReserveRatio").click(calculateReserveRatio);
  $("#calculateThreshold").click(calculateThreshold);
  $("#calculateVpools").click(calculateVpools);
  $("#clearLog").click(clearLog);
  $("#testNums").click(testNums);
  $("#showSwap").click(showSwap);
  $("#swapBtn").click(makeSwap);
  $("#quoteBtn").click(quote);
  $("#exchangeReserves").click(exchangeReserves);
  $("#IndirectCost").click(IndirectCost);
  $("#directCost").click(directCost);
  $("#virtuswapCost").click(virtuswapCost);

  $(document).on("click", ".rpoolToken", async (ev) => {
    $(".rpoolToken").removeClass("selected");
    $(ev.currentTarget).addClass("selected");
    await getPoolReserves(
      ev.currentTarget.dataset.tokena,
      ev.currentTarget.dataset.tokenb
    );
  });

  let socket = new WebSocket("ws://localhost:3000/echo");

  socket.onopen = function (e) {};

  socket.onmessage = function (ev) {
    $("#textArea").append(ev.data + "\n");

    var psconsole = $("#textArea");
    if (psconsole.length)
      psconsole.scrollTop(psconsole[0].scrollHeight - psconsole.height());
  };
});
