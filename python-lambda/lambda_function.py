"""
🔥 闘魂Python Lambda関数

シンプルなPython Lambda関数の実装例
後でElixirに移行するためのプロトタイプ
"""

import json
import logging
from datetime import datetime
from typing import Dict, Any

# ログ設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda エントリポイント
    
    Args:
        event: Lambdaイベントデータ
        context: Lambdaランタイムコンテキスト
        
    Returns:
        Dict: APIGatewayレスポンス形式
    """
    try:
        logger.info("🔥 闘魂Python Lambda 開始!")
        logger.info(f"受信イベント: {json.dumps(event, ensure_ascii=False)}")
        
        # リクエストIDの取得
        request_id = getattr(context, 'aws_request_id', 'unknown') if context else 'local'
        
        # 現在時刻
        current_time = datetime.utcnow().isoformat() + 'Z'
        
        # 闘魂メッセージの処理
        input_message = event.get('message', '闘魂注入!')
        test_param = event.get('test', 'default')
        
        # レスポンスデータの構築
        response_data = {
            "message": f"🔥 闘魂Python Lambda 成功だ！ - {input_message}",
            "timestamp": current_time,
            "request_id": request_id,
            "python_version": get_python_version(),
            "input_event": event,
            "processed_by": "Python闘魂エンジン",
            "status": "VICTORY!",
            "toukon_power": "MAX",
            "test_param": test_param
        }
        
        # APIGateway形式のレスポンス
        response = {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json; charset=utf-8",
                "X-Toukon-Power": "MAX",
                "X-Python-Engine": "True"
            },
            "body": json.dumps(response_data, ensure_ascii=False, indent=2)
        }
        
        logger.info("🔥 闘魂Python Lambda 完了!")
        return response
        
    except Exception as e:
        logger.error(f"💥 闘魂エラー発生: {str(e)}", exc_info=True)
        
        # エラーレスポンス
        error_response = {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json; charset=utf-8",
                "X-Toukon-Error": "True"
            },
            "body": json.dumps({
                "error": "闘魂処理でエラーが発生しました",
                "message": str(e),
                "timestamp": datetime.utcnow().isoformat() + 'Z',
                "status": "ERROR"
            }, ensure_ascii=False, indent=2)
        }
        
        return error_response


def get_python_version() -> str:
    """Pythonバージョンを取得"""
    import sys
    return f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"


# ローカルテスト用のメイン関数
if __name__ == "__main__":
    # テストイベント
    test_event = {
        "test": "toukon",
        "message": "Python闘魂テスト from ローカル"
    }
    
    # テスト実行
    result = lambda_handler(test_event, None)
    print("🔥 テスト結果:")
    print(json.dumps(result, ensure_ascii=False, indent=2))
