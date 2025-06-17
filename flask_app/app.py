from flask import Flask
import pymysql, os

app = Flask(__name__)

def get_db_connection():
    return pymysql.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASS'),
        db=os.getenv('DB_NAME'),
        cursorclass=pymysql.cursors.DictCursor
    )

@app.route("/")
def index():
    conn = get_db_connection()
    try:
        with conn.cursor() as c:
            c.execute("CREATE TABLE IF NOT EXISTS test (id INT AUTO_INCREMENT PRIMARY KEY, text VARCHAR(255));")
            c.execute("INSERT INTO test (text) VALUES ('Hello from Flask to RDS');")
            conn.commit()
            c.execute("SELECT text FROM test ORDER BY id DESC LIMIT 1;")
            return c.fetchone()["text"]
    finally:
        conn.close()

if __name__=="__main__":
    app.run(host="0.0.0.0", port=5000)
