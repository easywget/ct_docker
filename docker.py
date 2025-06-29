import subprocess

def run(cmd):
    print(f"Running: {cmd}")
    subprocess.run(cmd, shell=True, check=True)

# 1. Update system
run("apt update && apt upgrade -y")

# 2. Install dependencies
run("apt install -y ca-certificates curl gnupg lsb-release")

# 3. Add Docker GPG key
run("mkdir -p /etc/apt/keyrings")
run("curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg")

# 4. Set up Docker repo
run("""echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null""")

# 5. Update and install Docker
run("apt update")
run("apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin")

# 6. Test Docker
run("docker --version")
