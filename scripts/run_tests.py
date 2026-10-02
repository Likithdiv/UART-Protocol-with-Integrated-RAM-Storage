"""Run UART regressions with Icarus Verilog; leave generated files outside the repo."""
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
RTL = [str(path) for path in sorted((ROOT / "src").glob("*.v"))]


def run(command):
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    compiler = shutil.which("iverilog")
    simulator = shutil.which("vvp")
    if not compiler or not simulator:
        raise SystemExit("Install Icarus Verilog and add iverilog and vvp to PATH.")
    with tempfile.TemporaryDirectory(prefix="uart-tests-") as directory:
        executable = str(pathlib.Path(directory) / "test.vvp")
        for divisor in (8, 9, 100, 20000):
            run([compiler, "-g2012", "-Wall", "-s", "uart_top_tb",
                 f"-Puart_top_tb.DIV={divisor}", "-o", executable,
                 *RTL, "sim/uart_top_tb.v"])
            run([simulator, executable])
        run([compiler, "-g2012", "-Wall", "-s", "uart_ram_tb", "-o",
             executable, "src/uart_ram.v", "sim/uart_ram_tb.v"])
        run([simulator, executable])
        run([compiler, "-g2012", "-s", "uart_top_tb", "-Puart_top_tb.DIV=7",
             "-o", executable, *RTL, "sim/uart_top_tb.v"])
        result = subprocess.run([simulator, executable], cwd=ROOT,
                                capture_output=True, text=True)
        if result.returncode == 0 or "must be at least 8" not in result.stdout + result.stderr:
            raise SystemExit("FAIL: unsupported baud divisor was not rejected.")
        print("PASS: unsupported divisor rejected; all regressions passed.")


if __name__ == "__main__":
    main()
