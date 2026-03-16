import initWasm, {
  WebWallet,
  initThreadPool,
  generate_seed_phrase
} from "@chainsafe/webzjs-wallet";

const statusEl = document.getElementById("status") as HTMLDivElement;
const outputEl = document.getElementById("output") as HTMLPreElement;

const gatewayUrlInput = document.getElementById("gatewayUrl") as HTMLInputElement;
const networkInput = document.getElementById("network") as HTMLSelectElement;
const minConfInput = document.getElementById("minConf") as HTMLInputElement;

const accountNameInput = document.getElementById("accountName") as HTMLInputElement;
const accountIndexInput = document.getElementById("accountIndex") as HTMLInputElement;
const birthdayHeightInput = document.getElementById("birthdayHeight") as HTMLInputElement;

const connectBtn = document.getElementById("connectBtn") as HTMLButtonElement;
const latestBlockBtn = document.getElementById("latestBlockBtn") as HTMLButtonElement;
const walletSummaryBtn = document.getElementById("walletSummaryBtn") as HTMLButtonElement;
const seedBtn = document.getElementById("seedBtn") as HTMLButtonElement;
const createAccountBtn = document.getElementById("createAccountBtn") as HTMLButtonElement;
const currentAddressBtn = document.getElementById("currentAddressBtn") as HTMLButtonElement;

let wasmReady = false;
let wallet: WebWallet | null = null;
let currentAccountId: number | null = null;
let seedPhrase: string | null = null;

function setStatus(message: string) {
  statusEl.textContent = message;
}

function appendOutput(title: string, payload: unknown) {
  const block = [
    `# ${title}`,
    typeof payload === "string" ? payload : JSON.stringify(payload, null, 2),
    ""
  ].join("\n");
  outputEl.textContent = `${block}${outputEl.textContent}`;
}

async function ensureWallet(): Promise<WebWallet> {
  if (!wasmReady) {
    setStatus("Initializing WebZjs WASM...");
    await initWasm();

    const threads = Math.max(1, Math.min(8, navigator.hardwareConcurrency || 4));
    await initThreadPool(threads);
    wasmReady = true;
  }

  if (!wallet) {
    const network = networkInput.value as "main" | "test";
    const url = gatewayUrlInput.value.trim();
    const minConf = Number(minConfInput.value || 0);
    const minConfUntrusted = minConf;

    wallet = new WebWallet(network, url, minConf, minConfUntrusted);
    setStatus(`Wallet ready (${network})`);
  }

  return wallet;
}

connectBtn.addEventListener("click", async () => {
  try {
    wallet = null;
    currentAccountId = null;
    await ensureWallet();
    appendOutput("Wallet Initialized", {
      network: networkInput.value,
      gateway: gatewayUrlInput.value,
      minConfirmations: Number(minConfInput.value || 0)
    });
  } catch (err) {
    setStatus("Init failed");
    appendOutput("Init Error", String(err));
  }
});

latestBlockBtn.addEventListener("click", async () => {
  try {
    const w = await ensureWallet();
    setStatus("Fetching latest block...");
    const latest = await w.get_latest_block();
    setStatus("Latest block fetched");
    appendOutput("GetLatestBlock", latest.toString());

    const latestHeight = Number(latest);
    if (!Number.isNaN(latestHeight)) {
      birthdayHeightInput.value = String(latestHeight);
    }
  } catch (err) {
    setStatus("Latest block failed");
    appendOutput("GetLatestBlock Error", String(err));
  }
});

walletSummaryBtn.addEventListener("click", async () => {
  try {
    const w = await ensureWallet();
    setStatus("Fetching wallet summary...");
    const summary = await w.get_wallet_summary();
    setStatus("Wallet summary fetched");
    appendOutput("GetWalletSummary", summary);
  } catch (err) {
    setStatus("GetWalletSummary failed");
    appendOutput("GetWalletSummary Error", String(err));
  }
});

seedBtn.addEventListener("click", async () => {
  try {
    await ensureWallet();
    seedPhrase = await generate_seed_phrase();
    appendOutput("Generated Seed Phrase", seedPhrase);
  } catch (err) {
    appendOutput("Seed Phrase Error", String(err));
  }
});

createAccountBtn.addEventListener("click", async () => {
  try {
    const w = await ensureWallet();
    if (!seedPhrase) {
      appendOutput("Create Account", "Generate a seed phrase first.");
      return;
    }

    const accountName = accountNameInput.value.trim() || "demo";
    const accountIndex = Number(accountIndexInput.value || 0);
    const birthday = Number(birthdayHeightInput.value || 0);

    setStatus("Creating account...");
    currentAccountId = await w.create_account(
      accountName,
      seedPhrase,
      accountIndex,
      birthday
    );
    setStatus("Account created");
    appendOutput("CreateAccount", { accountId: currentAccountId });
  } catch (err) {
    setStatus("Create account failed");
    appendOutput("CreateAccount Error", String(err));
  }
});

currentAddressBtn.addEventListener("click", async () => {
  try {
    const w = await ensureWallet();
    if (currentAccountId === null) {
      appendOutput("GetCurrentAddress", "Create an account first.");
      return;
    }

    setStatus("Fetching current address...");
    const address = await w.get_current_address(currentAccountId);
    setStatus("Current address fetched");
    appendOutput("GetCurrentAddress", address);
  } catch (err) {
    setStatus("GetCurrentAddress failed");
    appendOutput("GetCurrentAddress Error", String(err));
  }
});

setStatus("Idle");
