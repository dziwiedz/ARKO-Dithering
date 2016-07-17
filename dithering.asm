.data
zapytanie_in:		.asciiz 	"Podaj sciezke pliku do wczytania wraz z rozszezneniem .bmp		: "
zapytanie_out:		.asciiz 	"Podaj sciezke wraz z nazwa plik do zapisu wraz z rozszerzeniem .bmp	: "
blad_wczytania: 	.asciiz 	"Blad wczytywania. Podano zla nazwe pliku."
zakonczenie:		.asciiz		"Pomyslnie zapisano plik."
path:			.space 		128
naglowek:		.space 		62

.text
	li	$v0, 4
	la	$a0, zapytanie_in
	syscall
	
	li	$v0, 8
	la	$a0, path
	li	$a1, 200
	syscall
	
	move	$t0, $a0
	move	$t1, $a0
	subiu	$t1, $t1, 1
	jal	usunEnter		
	
	#WCZYTANIE PLIKU DO ZMIENIENIA
	li	$v0, 13
	move	$a0, $t0
	li	$a1, 0
	li	$a2, 0
	syscall
	move	$t7, $v0 #ZAPAMIETANIE ADRESU W $T7
	beq	$t7, -1, blad

	#wczytanie naglowka
	move	$a0, $t7
	li	$v0, 14
	la	$a1, naglowek	
	la	$a2, 62
	syscall	
	move	$s7, $a1
#===========================================================================================
	#zapisywanie naglowka
	li	$t1, 40
	sb	$t1, 14($s7)
	li	$t1, 1
	sb	$t1, 26($s7)		#biPlanes
	sb	$t1, 28($s7)		#biBitCount
	usw	$zero, 54($s7)	
	usw	$zero, 34($s7)		
	usw	$zero, 38($s7)
	usw	$zero, 42($s7)	
	li	$t1, 16777215			
	usw	$t1, 58($s7)		#biRGB
	
	
	#obliczamy ilosc bajtow w rzedzie
	ulw	$s4, 18($s7) #szerokosc 	
	li	$t1, 4
	andi	$t0, $s4, 3
	beqz	$t0, zgodnaIloscPixeli		#jezeli jest podzielne przez 4, szerokosc jest wielokrotnoscia 4
	sub	$t0, $t1, $t0			#4-reszta=> ilosc zer uzytych do wyrownania
zgodnaIloscPixeli:
	addu	$s6, $t0, $s4			# ilosc bajtow na wiersz
	
	#alokacja pamieci
	ulw	$t0, 2($s7)	#rozmiar pliku wczytanego
	subiu	$t0, $t0, 62
	li	$v0, 9
	la	$a0, ($t0)
	syscall
	move	$s0, $v0 #adres pocztkowy zarezerwowanej pamieci ustawiamy w $s0
	
	#wczytanie obrazu do zaalokowanej pamiêci==================================
	move	$a0, $t7
	li	$v0, 14
	la	$a1, ($s0)
	la	$a2, ($t0)
	syscall
	
	#zamkniecie pliku
	li	$v0, 16
	move	$a0, $t7
	syscall
	
	ulw	$s5, 22($s7)	# wysokosc
	move	$s1, $s0	
	ulw	$t0, 10($s7)	# biOffBits
	subiu	$t0, $t0, 62
	addu	$s1, $s1, $t0	
	# $s0 - wskaznik na 1 pixel nowej mapy 1bpp
	# $s1 - wskaznik na 1 pixel wczytanej mapy kolorow 8bpp
	# $s2 - wskaznik pomocniczy dla powyzszych
	# $s4 - szerokosc
	# $s5 - wysokosc
	# $s6 - ilosc bajtow na wiersz
#=============================================================================================================================
#		PROPAGACJA BLEDU	

	move	$t4, $s5		# wysokosc do konca
	move	$t3, $zero		# licznik szerkosci
	move	$t5, $s6		# +/- bajty na rzad
	move	$s2, $s1		# $s2 wskazuje poczatek mapy kolorow 8bpp
	li	$t6, 1			# 1 oznacza propagowanie w gore,poruszanie sie w prawo, -1 propgowanie w dol, poruszanie sie w lewo
	move	$t2, $zero		# blad
	
prop:
	jal	propagacja
	addiu	$t3, $t3, 1		#ile juz przeszlismy pixeli
	beq	$t3, $s4, SprawdzKoniec
	addu	$s2, $s2, $t6
	j	prop
	
propagacja:	# 
	lbu	$t0, ($s2)		# KOLOR
	addu	$t0, $t0, $t2		# KOLOR = KOLOR + BLAD
	sge	$t1, $t0, 128
	beqz	$t1, ObliczBlad
	li	$t1, 255		#jezeli wieksze od 127, WYJSCIE=255
ObliczBlad:
	subu	$t2, $t0, $t1		# BLAD = KOLOR - WYJSCIE 
	sb	$t1, ($s2)
	jr	$ra

SprawdzKoniec:
	beq	$t4, 1, SprawdzCzyDol	
propKolumna:
	move	$t3, $zero		# zerujemy licznik pixeli
	addu	$s2, $s2, $t5		#przenosimy nad lub pod
	jal	propagacja
	subu	$t5, $zero, $t5		# -Bajty na rzad
	subu	$t6, $zero,  $t6	#zmiana kierunku propagacji
	addu	$s2, $s2, $t5		#powrot do poprzedniego
	addu	$s2, $s2, $s6		# pzeniesienie o wiersz wyzej
	beq	$t6, -1, Przesun
	move	$t3, $zero
Przesun:
	subiu	$t4, $t4, 1
	bnez	$t4, prop
SprawdzCzyDol:
	beq	$t6, -1, propKolumna #jezeli nie propaguje na dol, konczy
	

#=============================================================================================================================
#		ZAPISYWANIE MAPY MONOCHROMATYCZNEJ
	# obliczamy ile pustych bajtow musimy zapisywac na koncu wiersza mapy 1bpp
	andi	$t0, $s4, 31
	beqz	$t0, JestWyrownane   
	andi	$t5, $t0, 7
	srl	$t0, $t0, 3
	beqz	$t5, PoprawnaDlugoscBajtu
	addiu	$t0, $t0, 1		#jezeli zostala reszta, to znaczy ze dodatkowy bajt jest potrzebny by zapisac wszystkie kolory w wierszu
PoprawnaDlugoscBajtu:
	li	$t1, 4
	subu	$t3, $t1, $t0		# $t3=4-(ilosc potrzebnych bajtow do zapisu ostatnich kolorow w wierszu)
JestWyrownane:				

	move 	$s2, $s0		# pomocniczy wskaznik dla mapy 1 bpp
	move	$t5, $zero		# tutaj zapisujemy bajt
	li	$t1, 128		# aktualny bit
	move	$t4, $s4		# licznik szerokosci
	subu	$t2, $s6, $s4		# ilosc pustych bajtow na koncu wiersza mapy 8bpp
	
petla:					#=>PETLA ZAPISUJACA MAPE KOLOROW MONOCHROMATYCZNYCH
	lbu	$t0, ($s1)		#wczytane bajtu
	addiu	$s1, $s1, 1		#przesuwamy sie wskaznikiem mapy 8bpp naprzod
	beqz	$t0, CzarnyPixel
	or	$t5, $t5, $t1		
CzarnyPixel:
	subiu	$t4, $t4, 1		#pozostala ilosc pixeli do wczytania 
	beqz	$t4, zapiszPixel	#jezeli nie pozostal zaden pixel do wczytania, zapisujemy aktualny bajt
	srl 	$t1, $t1, 1		#dzielimy przez 2 aktualna wartosc bitu
	bnez	$t1, petla		#jezeli byl to 8 zapisany bit, wartosc $t1 bedzie wynosila 0
zapiszPixel:
	sb	$t5, ($s2)		#zapis bitu w mapie monochromatycznej
	li	$t1, 128		#ustawiamy aktualna wartosc na 128
	addiu	$s2, $s2, 1		#przesuway wskaznik mapy 1bpp
	move	$t5, $zero		#aktualny bajt ustawiamy na 0
	bnez	$t4, petla		#sprawdzenie czy nastapil koniec wiersza
koniecWiersza:
	move	$t4, $s4		# ponawiamy szerokosc
	addu	$s1, $s1, $t2		#$s5 - ilosc bajtow sluzacych jako wyrowanie do 4 pixeli, przesuwamy mape 8bpp a ta wartosc
	beqz 	$t3, nastWiersz		#$s4 - sprawdzenie czy trzeba wyrownac do 4 bajtow ($s4-ile pustych bajtow ma zostac zapsanych), jezeli nie, to przeskakujemy
	move	$t0, $zero		#licznik
zapiszZera:				#zapisujemy ($t3) zerowych bajtow
	addiu	$t0, $t0, 1
	sb	$zero, ($s2)
	addu	$s2, $s2, 1
	bne	$t0, $t3, zapiszZera	
nastWiersz:
	subiu	$s5, $s5, 1		#przejscie do nastepnego wiersza, $s5-wysokosc obrazu
	bnez	$s5, petla		#jezeli nie pozostal nam zaden wiersz, wychodzimy

#=============================================================================================================================
#		WYJSCIE Z PROGRAMU
exit:	

	li	$v0, 4
	la	$a0, zapytanie_out
	syscall
	
	li	$v0, 8
	la	$a0, path
	li	$a1, 200
	syscall
	move	$t7, $a0
	move	$t1, $a0
	
	subiu	$t1, $t1, 1
	jal	usunEnter

	# OPRACOWANIE ROZMIARU PLIKU
	subu	$t0, $s2,$s0	#$s3-wskazuje na pierwszy element za ostatnim bajtem zapisanym, $s0 poczatek, roznica da nam ilosc bajtow ktore sa w mapie kolorow
	move	$t2, $t0	#zapisujemy sobie $t2 by wykorzystac pozniej do zapisu danych
	addiu	$t0, $t0, 62	#calkowity rozmiar to 62bajty naglowka+rozmiar mapy kolorow
	usw	$t0, 2($s7)
	li	$t1, 62
	usw	$t1, 10($s7)	#nowe przesuniecie, starsze pochodzilo z mapy 8bpp
	
	# UTWORZENIE PLIKU
	la	$a0, ($t7)
	li	$a2, 0
	li	$a1, 1
	li	$v0, 13
	syscall
	move	$t7, $v0
	
	# ZAPIS NAGLOWKA
	move	$a0, $t7
	li	$v0, 15
	la	$a1, ($s7)
	li	$a2, 62
	syscall
	
	# ZAPIS MAPY KOLOROW 1BPP
	move	$a0, $t7
	li	$v0, 15
	la	$a1, ($s0)
	move	$a2, $t2
	syscall
	
	# ZAMKNIECIE PLIKU
	li	$v0, 16
	move	$a0, $t7
	syscall
	
	li	$v0, 4
	la	$a0, zakonczenie
	syscall
	
	# WYJSCIE Z PROGRAMU
	li	$v0, 10
	syscall
	
usunEnter:
	addiu	$t1, $t1, 1
	lbu	$t2, ($t1)
	bne	$t2, '\n', usunEnter
	sb	$zero, ($t1)
	jr	$ra
blad:
	li	$v0, 4
	la	$a0, blad_wczytania
	syscall
	li	$v0, 10
	syscall	