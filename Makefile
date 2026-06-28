.PHONY: up down clean restart logs status health validate security-scan setup

# ── Lifecycle ──────────────────────────────────────────────────────────────
up:
	docker compose up --build -d
	@echo "Stack started. Run 'make health' to check status."

down:
	docker compose down

clean:
	docker compose down -v

restart:
	docker compose restart

logs:
	docker compose logs -f

status:
	docker compose ps

# ── Validation ─────────────────────────────────────────────────────────────
health:
	@curl -s http://localhost:3000/health | python3 -m json.tool 2>/dev/null || \
	 curl -s http://localhost:3000/health

validate:
	@bash scripts/validate.sh

# ── Full setup (first-run) ─────────────────────────────────────────────────
setup:
	@bash scripts/setup.sh

# ── Security scanning (requires docker) ───────────────────────────────────
security-scan:
	@echo "--- npm audit ---"
	cd src && npm install --silent && npm audit --audit-level=critical || true
	@echo ""
	@echo "--- Hadolint (Dockerfile lint) ---"
	docker run --rm -i -v "$(PWD)/.hadolint.yaml:/.config/hadolint.yaml" \
	  hadolint/hadolint < src/Dockerfile
	@echo ""
	@echo "--- Trivy image scan ---"
	docker build -t observability-app:scan ./src --quiet
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
	  aquasec/trivy image --severity HIGH,CRITICAL --exit-code 0 \
	  observability-app:scan
	@echo ""
	@echo "--- Trivy config scan (IaC) ---"
	docker run --rm -v "$(PWD):/project" \
	  aquasec/trivy config --severity HIGH,CRITICAL --exit-code 0 /project
