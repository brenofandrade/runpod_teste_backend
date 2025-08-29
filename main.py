from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/health")
def check_health():
    """Endpoint para verificar se a API está ativa"""
    return jsonify({"status": "ok"}), 200


@app.post("/chat")
def chat():
    """
    Recebe um JSON {"message": "..."} e retorna a mesma mensagem
    junto com o status de validação.
    """
    data = request.get_json(silent=True)

    if not data or "message" not in data:
        return jsonify({
            "status": "error",
            "error": "Campo 'message' é obrigatório no JSON"
        }), 400

    message = data["message"]

    return jsonify({
        "status": "success",
        "message": message
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
