from flask import Flask, jsonify, request
from flask_cors import CORS
app = Flask(__name__)
CORS(app) 

@app.get("/health")
def check_health():
    """Endpoint para verificar se a API está ativa"""
    return jsonify({"status": "ok"}), 200


@app.route("/chat", methods=["POST", "GET"])
def chat():
    """
    Recebe um JSON {"message": "..."} e retorna a mesma mensagem
    junto com o status de validação.
    """
    if request.method == "GET":
        return jsonify({"status": "ready", "hint": "Use POST com JSON {\"message\": \"...\"}"}), 200

    # Tenta JSON, depois form; por fim, texto cru
    data = request.get_json(silent=True) or request.form or {}
    message = data.get("message") or request.data.decode("utf-8").strip()

    if not message:
        return jsonify({"status": "error", "error": "Campo 'message' é obrigatório"}), 400

    return jsonify({"status": "success", "message": message}), 200


if __name__ == "__main__":
    # Se usar waitress em produção, rode com:
    # waitress-serve --listen=0.0.0.0:8000 main:app
    app.run(host="0.0.0.0", port=8000, debug=True)
