import serial
import time


try:
    ser = serial.Serial('/dev/ttyUSB0', 9600)
    time.sleep(2)
    while True:
        data1 = ser.readline().decode('utf-8').strip()
        try:
            temperature = float(data1)
            if temperature> 35.6:
                print(f'Votre temperature est de {temperature} ')
                break
        except ValueError:
                print(f'Erreur de conversion des donnees : {data1}')
except serial.SerialException as e:
    print(f'Erreur de connexion au port serie: {e}')

try:
    ser = serial.Serial('/dev/ttyUSB1',57600)
    time.sleep(2)
    while True:
        if ser.in_waiting>0:
            data = ser.readline().decode('utf-8').strip()
            try:
                poids = float(data)
                if poids > 2:
                    print(f'Votre poids est de {poids} Kg')
                    break
            except ValueError:
                    print(f'Erreur de conversion des donnees : {data}')
except serial.SerialException as e:
        print(f'Erreur de connexion au port serie: {e}')
try:
    ser = serial.Serial('/dev/ttyACM0', 9600)
    time.sleep(2)
    while True:
        data3 = ser.readline().decode('utf-8').strip()
        try:
            data3= int(data3)
            if data3 == 310502:
                print(f'valide')
                break
        except ValueError:
                print(f'Erreur de conversion des donnees : {data3}')
except serial.SerialException as e:
    print(f'Erreur de connexion au port serie: {e}')


"""
try:
    ser = serial.Serial('/dev/ttyUSB2', 9600)
    time.sleep(2)
    while True:
        data2 = ser.readline().decode('utf-8').strip()
        try:
            taille = float(data2)
            if taille> 0.9:
                print(f'Votre taille est de {taille} ')
                #return taille
                break
        except ValueError:
            print(f'Erreur de conversion des donnees : {data2}')
except serial.SerialException as e:
    print(f'Erreur de connexion au port serie: {e}')

"""
