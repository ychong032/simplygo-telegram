import json
import requests
import simplygo
import os
from datetime import datetime

aws_session_token = os.environ.get('AWS_SESSION_TOKEN')
user_count = int(os.environ.get('USER_COUNT'))
headers = {'X-Aws-Parameters-Secrets-Token': aws_session_token}
ssm_url = 'http://localhost:2773/systemsmanager/parameters/get/'

def get_secrets() -> dict[str, str]:
    bot_token_path = '/simplygo-telegram/bot_token'
    user_path_prefix = '/simplygo-telegram/user'
    config = {}
    chats = {}

    for i in range(user_count):
        path = user_path_prefix + str(i)
        secret_value = get_secret(path)
        chat_id, username, password = secret_value.split(':')
        chats[chat_id] = {'username': username, 'password': password}
    
    bot_token = get_secret(bot_token_path)

    config['chats'] = chats
    config['message_url'] = f'https://api.telegram.org/bot{bot_token}/sendMessage'

    return config

def get_secret(path: str) -> str:
    params = {'name': path, 'withDecryption': 'true'}
    response = requests.get(ssm_url, params=params, headers=headers)
    response = response.json()

    return response['Parameter']['Value']

def lambda_handler(event, _):
    try:
        config = get_secrets()
        message_url = config['message_url']
        body = event['body']
        
        if type(body) is str:  # i.e. triggered by Telegram chat
            body = json.loads(body)

        user_input = ''
        message_prefix = ''
        chat_id = ''
        is_scheduled_message = False

        if 'CronScheduleType' in body:
            is_scheduled_message = True
            cronScheduleType = body['CronScheduleType']
            message_prefix = f'🤖 <i>This is your auto-generated {cronScheduleType} transaction report.</i>\n\n'
            if cronScheduleType == 'daily':
                user_input = '/today'
            elif cronScheduleType == 'monthly':
                user_input = '/month'
            else:
                return
        else:
            message = body['message']
            chat_id = str(message['chat']['id'])
            if chat_id not in config['chats']:
                return
            user_input = message['text']
        
        if is_scheduled_message:
            for id, creds in config['chats'].items():
                try:
                    if os.path.exists('/tmp/simplygo.session'):
                        os.remove('/tmp/simplygo.session')

                    rider = simplygo.Ride(creds['username'], creds['password'])
                    bot_response = message_prefix + create_bot_response(user_input, rider)
                    data = {'chat_id': id, 'text': bot_response, 'parse_mode': 'HTML'}
                    _ = requests.post(message_url, data=data)
                except:
                    continue
        else:
            creds = config['chats'][chat_id]
            rider = simplygo.Ride(creds['username'], creds['password'])
            bot_response = message_prefix + create_bot_response(user_input, rider)
            data = {'chat_id': chat_id, 'text': bot_response, 'parse_mode': 'HTML'}
            _ = requests.post(message_url, data=data)
    except Exception as e:
        print(e)
        return

def create_bot_response(user_input: str, rider: simplygo.Ride) -> str:
    if user_input.startswith('/'):
        string_after_slash = user_input.replace('/', '', 1)
        if len(string_after_slash) == 0:
            return 'Sorry, you need to enter a valid command after the slash.'
        command = string_after_slash.split(' ')[0]
        match command:
            case 'today':
                return get_txns_for_today(rider)
            case 'month':
                return get_txns_for_this_month(rider)
            case 'start':
                return 'Hey there! Type one of the available commands to get started!'
            case _:
                return 'Sorry, I don\'t recognise that command.'
    return 'Type "/" without the quotes to view the available commands.'

def get_txns_for_today(rider: simplygo.Ride) -> str:
    card_info = rider.get_card_info()
    if len(card_info) == 0:
        return 'You have no cards registered!'
    
    card_id = card_info[0]['UniqueCode']
    data = rider.get_transactions(card_id)
    records = data['Histories']
    journeys_by_date, total_fare = get_journeys_and_total_fare(records)

    return generate_summary(journeys_by_date, total_fare)

def get_txns_for_this_month(rider: simplygo.Ride) -> str:
    card_info = rider.get_card_info()
    if len(card_info) == 0:
        return 'You have no cards registered!'

    card_id = card_info[0]['UniqueCode']

    data = rider.get_transactions_this_month()
    if card_id not in data.keys():
        return 'No transactions recorded for this month!'
    
    records = data[card_id]['Histories']
    journeys_by_date, total_fare = get_journeys_and_total_fare(records)
    
    return generate_summary(journeys_by_date, total_fare)

def get_journeys_and_total_fare(records: list[str]) -> tuple[dict[str, list[str]], float]:
    total_fare = 0
    current_day_journeys = []
    journeys_by_date = {}

    for record in records:
        if record['Type'] == 'Journey':
            entry_date = datetime.fromisoformat(record['EntryTransactionDate'])
            entry_time = entry_date.strftime('%H:%M')
            entry_location = record['EntryLocationName']
            exit_date = datetime.fromisoformat(record['ExitTransactionDate'])
            exit_time = exit_date.strftime('%H:%M')
            exit_location = record['ExitLocationName']
            fare_as_string = record['Fare']

            journey_string = f'{entry_location} ({entry_time}) --> {exit_location} ({exit_time}) -- <b>{fare_as_string}</b>'
            current_day_journeys.insert(0, journey_string)

            try:
                fare = float(fare_as_string[1:])
                total_fare += fare
            except ValueError:
                continue

            if record['No'] == 1:
                date = f"{entry_date.day} {entry_date.strftime('%b')}, {entry_date.strftime('%A')}"
                journeys_by_date[date] = current_day_journeys
                current_day_journeys = []

    return journeys_by_date, round(total_fare, 2)

def generate_summary(journeys_by_date: dict[str, list[str]], total_fare: float) -> str:
    result = ''
    if len(journeys_by_date) > 0:
        result += '🗒️ Journey and fare details:\n\n'
        for date in reversed(journeys_by_date):
            result += f'<u>{date}</u>\n'
            for journey in journeys_by_date[date]:
                result += f'{journey}\n'
            result += '\n'

        result += f'💸 Total fare: <b><u>${total_fare:.2f}</u></b>'
    
    return result if len(result) > 0 else '🤷 No transactions recorded for this period.'